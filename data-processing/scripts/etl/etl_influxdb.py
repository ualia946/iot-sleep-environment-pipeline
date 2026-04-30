import pandas as pd
from influxdb_client import InfluxDBClient
from datetime import datetime, timedelta, timezone
import dotenv
import os
import sys  

# Constantes
dotenv.load_dotenv()

TOKEN = os.getenv("INFLUXDB_TOKEN")
ORG = os.getenv("ORG")
BUCKET = os.getenv("BUCKET")
URL = os.getenv("URL_DOCKER")
MEASUREMENT = os.getenv("MEASUREMENT")
archivo_csv = "/app/datos_salida/sensores_habitacion.csv"

def main():
    client = conexion_influxdb()
    df = consulta_influxdb(client, 20, 12) 
    cargar_datos(df)

def conexion_influxdb() -> InfluxDBClient:
    if not TOKEN:
        print("No se ha introducido el token de InfluxDB. Abortando...")
        sys.exit(1)

    client = InfluxDBClient(url=URL, org=ORG, token=TOKEN)

    try:
        if client.ping():
            print("Conexión exitosa con InfluxDB")
        else:
            print("El servidor respondió, pero InfluxDB no parece estar listo.")
            sys.exit(1)
    except Exception as e:
        print("Se ha producido un error al conectarse con influxdb.\n")
        print(f"Detalles del error: {e}")
        sys.exit(1)
    
    return client

def consulta_influxdb(client: InfluxDBClient, horaInicio: int, horaFin: int) -> pd.DataFrame: 
    hoy = datetime.now(timezone.utc).replace(hour=horaInicio, minute=0, second=0, microsecond=0)
    ayer = (hoy - timedelta(days=1)).replace(hour=horaFin)

    formato_influx = "%Y-%m-%dT%H:%M:%SZ"

    start_time = ayer.strftime(formato_influx)
    stop_time = hoy.strftime(formato_influx)

    consulta_flux = f"""
    from(bucket: "{BUCKET}")
      |> range(start: {start_time}, stop: {stop_time})
      |> filter(fn: (r) => r["_measurement"] == "{MEASUREMENT}")
      |> aggregateWindow(every: 1m, fn: median, createEmpty: false)
      |> pivot(rowKey:["_time"], columnKey: ["topic"], valueColumn: "_value")
      |> drop(columns: ["_start", "_stop", "_measurement", "_field", "host", "result"])
    """

    query_api = client.query_api()

    df = query_api.query_data_frame(consulta_flux)
    df = df.drop(columns=['result', 'table'], errors='ignore')

    if df.empty:
        print(f"""No hay datos recopilados en este rango de tiempo.
               Inicio: {start_time}
               Fin: {stop_time}""")
        sys.exit(0) 
        
    print(f"Datos extraídos correctamente ({len(df)} filas).")
    return df

def cargar_datos(df: pd.DataFrame):
    if not os.path.isfile(archivo_csv):
        df.to_csv(archivo_csv, index=False)
        print(f"Archivo {archivo_csv} creado.")
    else:
        df.to_csv(archivo_csv, mode='a', header=False, index=False)
        print(f"Se han añadido {len(df)} nuevos registros al archivo {archivo_csv}")

if __name__ == "__main__":
    main()