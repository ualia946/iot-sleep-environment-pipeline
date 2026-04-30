#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include "secrets.h" 
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>
#include <DFRobot_ENS160.h>
#include <Wire.h>
#include <BH1750.h>


// WiFi y MQTT
const char* ssid = STASSID;
const char* password = STAPSK;
const char* mqtt_server = MQTT_SERVER;

WiFiClient espClient;
PubSubClient client(espClient);
unsigned long ultimoMensaje = 0;

// Mosquitto endpoints
const char* end_temperatura = "habitacion/temperatura";
const char* end_humedad = "habitacion/humedad";
const char* end_presion = "habitacion/presion";
const char* end_nivel_CO2 = "habitacion/nivel_CO2";
const char* end_aqi_cuantitativo = "habitacion/aqi_cuantitativo";
const char* end_aqi_cualitativo = "habitacion/aqi_cualitativo";
const char* end_compuestos = "habitacion/compuestos";
const char* end_luminosidad = "habitacion/luminosidad";
const char* end_sonido = "habitacion/sonido";

// SENSORES
Adafruit_BME280 bme280;
DFRobot_ENS160_I2C ens160 = DFRobot_ENS160_I2C(&Wire, 0x52);
BH1750 bh1750;
const int pinMicrofono = 34;


// ESTRUCTURAS
struct DatosClima
{
  float temperatura;
  float humedad;
};

// AMPLITUD DEL RUIDO
float amplitud_referencia = 30.0;

// 2. DECLARACIÓN DE FUNCIONES
void conectarWiFi();
void conectarMQTT();
void conectarBME280();
DatosClima leerBME280();
void conectarENS160();
void leerENS160(float temperatura, float humedad);
void conectarBH1750();
void leerBH1750();
int leerMicrofono();
void calcularDecibelios(int amplitud);
void calibrarMicrofono();

// 3. SETUP
void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);

  calibrarMicrofono();

  delay(2000);

  conectarWiFi();
  conectarMQTT();
  conectarBME280();
  conectarENS160();
  conectarBH1750();
}

// 4. LOOP
void loop() {
  client.loop();

  if(!WiFi.isConnected()){
    conectarWiFi();
  }
  
  if(!client.connected()){
    conectarMQTT();
  }

  unsigned long ahora = millis();
  if((ahora - ultimoMensaje) > 50000){
    ultimoMensaje = ahora;
    DatosClima clima = leerBME280();
    leerENS160(clima.temperatura, clima.humedad);
    leerBH1750();
    calcularDecibelios(leerMicrofono());
    Serial.println("Mensajes enviados...");
    Serial.println();
  }
}

// 5. DEFINICIÓN DE FUNCIONES
void conectarWiFi(){
  Serial.println();
  Serial.printf("Conectando a %s ", ssid);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nPlaca ESP32 conectada a WiFi");
  Serial.print("Dirección IP: ");
  Serial.println(WiFi.localIP());
}

void conectarMQTT(){
  client.setServer(mqtt_server, 1883);
  Serial.println("Realizando conexión MQTT... ");

  while (!client.connected()){
    Serial.print(".");
    if (client.connect("ESP32_Habitacion")){
      Serial.println("\n¡Conectado!");
    } else {
      Serial.print("\nError: ");
      Serial.print(client.state());
      Serial.println(" -> Volviendo a intentarlo en 5 segundos...");
      delay(5000);
    }
  }
}

void conectarBME280(){
  Serial.print("Conectando BME280...\n");
  if(!bme280.begin(BME280_ADDRESS)){
    Serial.println("Fallo en 0x76. Probando 0x77...");

    if(!bme280.begin(BME280_ADDRESS_ALTERNATE)){
      Serial.println("CRÍTICO. No se puede conectar el sensor BME280. Haz una revisión");
      while(1) {delay(10);}
    }
  }

  Serial.print("BME280 conectado.");
}

DatosClima leerBME280(){
  float temperatura = bme280.readTemperature();
  float humedad = bme280.readHumidity();
  float presion = bme280.readPressure()/100.0F;

  Serial.printf("Temperatura: %.2f ºC\n", temperatura);
  client.publish(end_temperatura, String(temperatura).c_str());

  Serial.printf("Humedad: %.2f %%\n", humedad);
  client.publish(end_humedad, String(humedad).c_str());

  Serial.printf("Presion: %.2f hPa\n", presion);
  client.publish(end_presion, String(presion).c_str());

  return {temperatura, humedad};
}

void conectarENS160(){
  if(ens160.begin() != NO_ERR){
    Serial.println("CRÍTICO. Fallo en ENS160.");
    while(1) { delay(10); }
  }
  ens160.setPWRMode(ENS160_STANDARD_MODE);
}

void leerENS160(float temperatura, float humedad){
  
  ens160.setTempAndHum(temperatura, humedad);

  uint16_t nivel_C02 = ens160.getECO2(); 
  uint8_t aqi = ens160.getAQI();
  uint16_t compuestos = ens160.getTVOC();

  const char* diccionario_aqi[] = {
    "Desconocido",
    "Excelente",
    "Bueno",
    "Moderado",
    "Pobre",
    "Muy malo"
  };

  Serial.printf("Nivel de CO2: %d ppm\n", nivel_C02);
  client.publish(end_nivel_CO2, String(nivel_C02).c_str());

  Serial.printf("Calidad del aire: %s (%d)\n", diccionario_aqi[aqi], aqi);
  client.publish(end_aqi_cualitativo, diccionario_aqi[aqi]);
  client.publish(end_aqi_cuantitativo, String(aqi).c_str());

  Serial.printf("Concentración de TVOC: %d ppb\n", compuestos);
  client.publish(end_compuestos, String(compuestos).c_str());
}

void conectarBH1750(){
  
  if(!bh1750.begin(BH1750::CONTINUOUS_HIGH_RES_MODE_2, 0x23, &Wire)){
    Serial.println("CRÍTICO. El sensor BH1750 no está conectado.");
    while(1) { delay(10); }
  }
  Serial.print("BH1750 conectado.");
}

void leerBH1750(){
  float luminosidad = bh1750.readLightLevel();
  
  Serial.printf("Luminosidad: %.2f lux\n", luminosidad);
  client.publish(end_luminosidad, String(luminosidad).c_str());
}

int leerMicrofono(){
  unsigned long inicioVentana = millis();
  int picoMaximo = 0;
  int picoMinimo = 4095;
  while (millis() - inicioVentana < 50){
    int lectura = analogRead(pinMicrofono);
    if(lectura > picoMaximo){
      picoMaximo = lectura;
    }
    if(lectura < picoMinimo){
      picoMinimo = lectura;
    }
  }
  int amplitud = picoMaximo - picoMinimo;
  return amplitud;
}

void calcularDecibelios(int amplitud){
  if(amplitud <= 0){
    amplitud = 1;
  }

  //Ruido de fondo. En este caso sería el ruido generado por los componente electrónicos.
  float db = 20.0 * log10(amplitud/amplitud_referencia);

  // Si el ruido de fondo es mayor que el medido, el resultado es negativo, por lo que serían 0 db de ruido.
  if(db < 0){
    db = 0;
  }

  Serial.printf("Decibelios: %.2f db \n", db);
  client.publish(end_sonido, String(db).c_str());
}

void calibrarMicrofono(){
  Serial.print("Estabilizando hardware analógico...\n");
  delay(3000);

  Serial.print("Calibrando micrófono (Silencio Absoluto)!\n");

  long sumaAmplitudes = 0;
  int numeroMuestras = 0;
  unsigned long tiempoInicio = millis();
  while (millis() - tiempoInicio < 5000){
    sumaAmplitudes+=leerMicrofono();
    numeroMuestras++;
  }

  amplitud_referencia = (float) sumaAmplitudes / numeroMuestras;
  if(amplitud_referencia <= 0){
    amplitud_referencia = 1;
  }
  Serial.printf("Microfono calibrado: %.2f(ruido de fondo)\n", amplitud_referencia);
}

