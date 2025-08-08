// PIN DEFS
//  LED_BUILTIN
int MOTHERBOARD = 10;
int FAN_PWM = 11;
int FAN_TACH = 2;

// SERIAL COMM DEFS
byte PING = 0;
byte PONG = 1;
byte RPM = 2;

// GLOBALs
float dutyCycle = 0.3;

// MOTHERBOARD PWM SIGNAL VARS
unsigned long highTime;
unsigned long lowTime;
unsigned long totalTime;

void measureMotherboardPWM() {
  highTime = pulseIn(MOTHERBOARD, HIGH); // HIGH pulse duration in microseconds
  lowTime = pulseIn(MOTHERBOARD, LOW);   // LOW pulse duration in microseconds
  
  // avoid divide-by-zero errors
  if (highTime > 0 || lowTime > 0) {
    // calculate duty cycle
    totalTime = highTime + lowTime;
    dutyCycle = (float)highTime / totalTime;
  }
}

// TACHOMETER VARS
unsigned long startTime;
int rpmCounter = 0;
int rpm;

void tachCount() {
  rpmCounter++;  
}

void tachUpdate() {
  unsigned long now = millis();
  if (now - startTime >= 1000) {
    // *60 to convert per second to per minute
    // /2 because the fan create 2 pulldowns per revolution
    rpm = rpmCounter * 60 / 2;

    // send RPM data to daemon
    Serial.write(RPM);
    Serial.write(3 + rpm / 12);
    
    rpmCounter = 0;
    startTime = now;
  }
}

// 4-pin fan PWM signal is at 5V 25Khz
int CYCLE_LEN = 1000 / 25; // in microseconds


void setup() {
  Serial.begin(9600);
  
  // pinMode(MOTHERBOARD, INPUT);
  pinMode(FAN_PWM, OUTPUT);
  attachInterrupt(digitalPinToInterrupt(FAN_TACH), tachCount, RISING);

  startTime = millis();
}

void loop() {  
  // send PWM signal to fan
  int dutyMicros = CYCLE_LEN * dutyCycle;
  digitalWrite(FAN_PWM, HIGH);
  delayMicroseconds(dutyMicros);
  digitalWrite(FAN_PWM, LOW);
  delayMicroseconds(CYCLE_LEN - dutyMicros);

  // recieve duty cycle from daemon
  if (Serial.available() > 0) {
    byte val = Serial.read();
    if (val == PING) {
      Serial.write(PONG);
    } else {
      dutyCycle = (float)val / 255.0;
    }
  }

  tachUpdate();
}

// extremely slow!!!
byte input[4];
byte readByteFromSerialString() {
  int bytesRead = Serial.readBytesUntil('\n', input, 4);

  byte val;
  if (bytesRead == 1) {
    val = input[0]-48;
  } else if (bytesRead == 2) {
    val = (input[0]-48)*10 + (input[1]-48);
  } else if (bytesRead == 3) {
    val = (input[0]-48)*100 + (input[1]-48)*10 + (input[2]-48);
  }

  return val;
}
