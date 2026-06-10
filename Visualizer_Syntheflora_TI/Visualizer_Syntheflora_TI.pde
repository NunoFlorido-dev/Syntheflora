import netP5.*;
import oscP5.*;
import processing.serial.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;


// --- OSC COMMUNICATION ---
OscP5 oscP5;
NetAddress myRemoteLocation;

// --- OSC VALUES ---
int currentColumn = 0;
int currentRow = 0;
int currentState = 0;
int potentiometerValue = 120;
int activeSequencerStep = 0;
float proxLeft = 0;
float proxRight = 0;
float pitch;
float snareSignal;


// --- CONFIGURAÇÕES DO SISTEMA ---
boolean simulationMode = true; // Muda para 'false' quando o Arduino estiver ligado
Serial myPort;
Minim minim;
AudioOutput out;
Oscil wave;
FFT fft;

// --- RESOLUÇÃO E ESCALA RESPONSIVA ---
int VIRTUAL_WIDTH = 1600;  // O espaço matemático onde o design foi feito
int VIRTUAL_HEIGHT = 900;
float scaleFactor;         // Calcula automaticamente o encolhimento

// --- VARIÁVEIS DE DADOS ---
//float proxLeft = 0;
//float proxRight = 0;
//int potentiometerValue = 0;
int currentDialStep = 1;
int lastDialStep = 1;
boolean humanPresent = false;
//int activeSequencerStep = 0;
int[] matrixArray = new int[8];

// --- TEMPORIZADORES ---
int audioPulseTimer = 0;
int sequencerTimer = 0;

// --- ESTILO VISUAL ---
color neonGreen = color(50, 255, 100);
color brightGreen = color(150, 255, 180);
color darkGreen = color(10, 50, 20);
color bgCol = color(5, 7, 5);
PFont font;
PFont segFont;
StringList systemLogs;

void setup() {
  // Podes alterar estes valores para o que quiseres, desde que mantenhas a proporção 16:9
  // (ex: 1280x720, 1366x768, 1024x576)
  size(1280, 720, P2D);
  smooth(4);
  frameRate(60);

  // OSC
  oscP5 = new OscP5(this, 9600);
  myRemoteLocation = new NetAddress("127.0.0.1", 9600);

  // Calcula o rácio de encolhimento do ecrã
  scaleFactor = (float)width / VIRTUAL_WIDTH;

  font = createFont("Monospaced", 18);
  segFont = createFont("AndaleMono", 48);
  textFont(font);

  systemLogs = new StringList();
  addLog("SYS_INIT [OK]");
  addLog("AWAITING BIO_INPUT...");

  minim = new Minim(this);
  out = minim.getLineOut();
  wave = new Oscil(440, 0.5f, Waves.SQUARE);
  wave.patch(out);
  wave.setAmplitude(0.0f);

  fft = new FFT(out.bufferSize(), out.sampleRate());
}


/// OSC EVENT
void oscEvent(OscMessage theOscMessage) {
  if (theOscMessage.checkAddrPattern("/step") == true) {
    currentColumn = theOscMessage.get(0).intValue();
    currentRow    = theOscMessage.get(1).intValue();
    currentState  = theOscMessage.get(2).intValue();

    activeSequencerStep = theOscMessage.get(0).intValue();
    matrixArray[currentColumn] = currentState;


    println(currentColumn);
  }
  if (theOscMessage.checkAddrPattern("/bpm") == true) {
    potentiometerValue = int(map(theOscMessage.get(0).intValue(), 50, 400, 0, 1023));
  }

  if (theOscMessage.checkAddrPattern("/pitch") == true) {
    pitch = theOscMessage.get(0).intValue();
  }

  if (theOscMessage.checkAddrPattern("/snare") == true) {
    snareSignal = theOscMessage.get(0).intValue();
  }
}

void draw() {
  background(bgCol);

  // --- GESTOR DO PULSO DE ÁUDIO ---
  if (audioPulseTimer > 0) {
    audioPulseTimer--;
    if (audioPulseTimer == 0) {
      wave.setAmplitude(0.0f);
    }
  }

  // --- MODO DE SIMULAÇÃO (Usa a largura real da janela) ---
  if (simulationMode) {
    proxLeft = constrain(lerp(proxLeft, int(map(pitch, 36, 83, 0, 100)), 0.05), 0, 100);
    proxRight = constrain(lerp(proxRight, map(snareSignal, -100, 0, 0, 100), 0.05), 0, 100);

    humanPresent = (proxLeft > 60);

    //potentiometerValue = (int)map(mouseY, height, 0, 0, 1023);
    currentDialStep = (int)map(potentiometerValue, 0, 1023, 1, 8);
    currentDialStep = constrain(currentDialStep, 1, 8);

    if (currentDialStep != lastDialStep) {
      addLog("TEMPO_CHANGED [STEP_" + currentDialStep + "]");
      lastDialStep = currentDialStep;
    }

    // int framesPerBeat = (int)map(currentDialStep, 1, 8, 60, 10);

    //sequencerTimer++;
    // if (sequencerTimer >= framesPerBeat) {
    //  sequencerTimer = 0;
    //activeSequencerStep = (activeSequencerStep + 1) % 8;
    //triggerSound();

    if (humanPresent && activeSequencerStep == 0) addLog("PLANT_TOUCH [ACTIVE]");
  }

  // ==========================================
  // INÍCIO DO DESENHO ESCALONADO
  // Tudo o que está aqui dentro será encolhido automaticamente
  // ==========================================
  pushMatrix();
  scale(scaleFactor);

  drawHUDGrid();
  drawSystemHeader(50, 45);

  // Linha 1
  drawBioMonitorPanel(50, 140, 740, 360);
  drawTempoDialPanel(810, 140, 740, 360);

  // Linha 2
  drawAudioSequencerPanel(50, 520, 1000, 340);
  drawLogsPanel(1070, 520, 480, 340);

  noFill();
  stroke(neonGreen, 80);
  strokeWeight(2);
  rect(15, 15, VIRTUAL_WIDTH - 30, VIRTUAL_HEIGHT - 30, 5);

  popMatrix();
  // FIM DO DESENHO ESCALONADO
}

// ==========================================
// FUNÇÕES DE DESENHO DO LAYOUT HUD
// ==========================================

void drawHUDGrid() {
  stroke(darkGreen, 60);
  strokeWeight(1);
  for (int x = 0; x < VIRTUAL_WIDTH; x += 40) line(x, 0, x, VIRTUAL_HEIGHT);
  for (int y = 0; y < VIRTUAL_HEIGHT; y += 40) line(0, y, VIRTUAL_WIDTH, y);
}

void drawSystemHeader(float x, float y) {
  pushMatrix();
  translate(x, y+10);
  fill(neonGreen);
  textSize(32);
  text("SYNTHEFLORA v2.7", 0, 0);
  textSize(16);
  fill(brightGreen, 200);
  text("BIO_INTERFACE MONITOR [SYSTEM_OK]  //  MODE: [REAL_AUDIO_REACT]", 0, 25);
  popMatrix();
}

void drawBioMonitorPanel(float x, float y, float w, float h) {
  pushMatrix();
  translate(x, y);
  drawPanelFrame(w, h, "BIO_METRIC MONITOR", "[HUD_BIO_01]");
  translate(30, 40);

  float meterW = 320;
  float barHeight = 25;

  fill(neonGreen);
  textSize(18);
  text("PLANT_PROXIMITY_MATRIX", 0, 10);

  translate(0, 50);
  fill(brightGreen, 200);
  textSize(14);
  text("L_HAND_CAP_SENSOR___[01]", 0, 0);
  stroke(darkGreen);
  fill(bgCol);
  rect(0, 10, meterW, barHeight);
  float pWL = map(proxLeft, 0, 100, 0, meterW);
  noStroke();
  fill(neonGreen, 180);
  rect(0, 10, pWL, barHeight);
  drawMeterScale(meterW, 10, barHeight);

  translate(0, 80);
  fill(brightGreen, 200);
  textSize(14);
  text("R_HAND_CAP_SENSOR___[02]", 0, 0);
  stroke(darkGreen);
  fill(bgCol);
  rect(0, 10, meterW, barHeight);
  float pWR = map(proxRight, 0, 100, 0, meterW);
  noStroke();
  fill(neonGreen, 180);
  rect(0, 10, pWR, barHeight);
  drawMeterScale(meterW, 10, barHeight);

  translate(400, -110);
  float avgProx = (proxLeft + proxRight) / 2.0;
  drawTechnicalPlantHelix(h - 80, avgProx);

  popMatrix();
}

void drawMeterScale(float w, float yOffset, float hOffset) {
  pushStyle();
  fill(neonGreen);
  textSize(10);
  for (int i = 0; i <= 10; i++) {
    float mx = map(i, 0, 10, 0, w);
    stroke(neonGreen, 100);
    line(mx, yOffset + hOffset, mx, yOffset + hOffset + 5);
    if (i % 2 == 0) text(i, mx - 3, yOffset + hOffset + 18);
  }
  popStyle();
}

void drawTempoDialPanel(float x, float y, float w, float h) {
  pushMatrix();
  translate(x, y);
  drawPanelFrame(w, h, "TEMPO_CONTROL [DIY_DIAL_VFD]", "[GRID_REF]");

  translate(w/2, h/2 - 20);
  noFill();
  stroke(darkGreen);
  strokeWeight(2);
  arc(0, 0, 200, 200, PI - QUARTER_PI, TWO_PI + QUARTER_PI);

  float ptrAngle = map(currentDialStep, 1, 8, PI - QUARTER_PI, TWO_PI + QUARTER_PI);
  stroke(brightGreen);
  strokeWeight(4);
  line(0, 0, cos(ptrAngle) * 90, sin(ptrAngle) * 90);
  fill(brightGreen);
  ellipse(0, 0, 15, 15);

  translate(0, 130);
  drawVFDDialSteps(currentDialStep);
  popMatrix();
}

void drawAudioSequencerPanel(float x, float y, float w, float h) {
  pushMatrix();
  translate(x, y);
  drawPanelFrame(w, h, "SEQ_ENGINE & AUDIO_SCOPE", "[REAL_TIME]");
  translate(20, 40);

  fill(neonGreen);
  textSize(18);
  text("STEP_ENGINE [8_PULSES]", 0, 0);

  translate(0, 30);
  float seqAreaW = (w / 2) - 40;
  float spacing = 8;
  float boxW = (seqAreaW - (spacing * 7)) / 8;
  float boxH = 80;

  drawVFDSequencerSteps(activeSequencerStep, boxW, boxH, spacing);

  translate(w / 2, -30);
  fill(neonGreen);
  text("REAL_TIME_SCOPE [WAVE & FFT]", 0, 0);

  float scopeW = (w / 2) - 40;
  float scopeH = h - 90;
  noFill();
  stroke(darkGreen);
  rect(0, 20, scopeW, scopeH);

  drawRealAudioScope(scopeW, scopeH);
  popMatrix();
}

void drawLogsPanel(float x, float y, float w, float h) {
  pushMatrix();
  translate(x, y);
  drawPanelFrame(w, h, "STATE_LOGS [SYSTEM_MONITOR]", "");
  translate(20, 40);
  fill(neonGreen);
  textSize(14);

  int maxLogs = (int)(h - 60) / 20;
  for (int i = 0; i < systemLogs.size(); i++) {
    int index = systemLogs.size() - 1 - i;
    if (i >= maxLogs) break;
    fill(neonGreen, map(i, 0, maxLogs, 250, 50));
    text("» " + systemLogs.get(index), 0, i * 20);
  }
  popMatrix();
}

// ==========================================
// FUNÇÕES AUXILIARES DE DESENHO (TÉCNICOS/VFD)
// ==========================================

void drawPanelFrame(float w, float h, String title, String ref) {
  noFill();
  stroke(darkGreen, 150);
  strokeWeight(1);
  rect(0, 0, w, h, 2);
  stroke(neonGreen, 200);
  strokeWeight(2);
  line(0, 0, 15, 0);
  line(0, 0, 0, 15);
  line(w, h, w-15, h);
  line(w, h, w, h-15);
  fill(neonGreen);
  textSize(14);
  textAlign(LEFT);
  text(title, 10, -5);
  textAlign(RIGHT);
  fill(darkGreen);
  text(ref, w-10, 15);
  textAlign(LEFT);
}

void drawTechnicalPlantHelix(float h, float avgProximity) {
  pushMatrix();
  textAlign(CENTER);
  if (avgProximity > 20) {
    fill(brightGreen);
    text("BIO_SIGN [ACTIVE]", 25, 0);
  } else {
    fill(darkGreen);
    text("BIO_SIGN [IDLE]", 25, 0);
  }

  translate(0, 30);
  noFill();
  strokeWeight(2);
  float res = (h - 40) / 20.0;

  stroke(darkGreen);
  for (int i = 0; i < 20; i++) {
    float yVal = i * res;
    float off = sin((frameCount*0.02) + i*0.5) * 20;
    line(off, yVal, off+50, yVal);
    ellipse(off+25, yVal, 5, 5);
  }

  if (avgProximity > 20) {
    stroke(brightGreen, map(avgProximity, 20, 100, 50, 255));
    float helixSteps = map(avgProximity, 20, 100, 0, 20);
    beginShape();
    for (int i = 0; i < helixSteps; i++) {
      float yVal = i * res;
      float angle = (frameCount*0.1) + i*0.8;
      float xVal = sin(angle) * 30 + 25;
      vertex(xVal, yVal);
      ellipse(xVal, yVal, 8, 8);
    }
    endShape();
  }
  textAlign(LEFT);
  popMatrix();
}

void drawVFDDialSteps(int activeStep) {
  textFont(segFont);
  textSize(36);
  textAlign(CENTER, CENTER);
  float stepW = 45;
  translate(-(stepW*8)/2.0 + (stepW/2.0), 0);

  for (int i = 1; i <= 8; i++) {
    float sx = (i-1) * stepW;
    fill(darkGreen, 80);
    text(i, sx, 0);

    if (i == activeStep) {
      fill(brightGreen);
      text(i, sx, 0);
      fill(neonGreen, 50);
      text(i, sx, 0);
    }
  }
  textFont(font);
  textAlign(LEFT);
}

void drawVFDSequencerSteps(int activeStep, float boxW, float boxH, float spacing) {
  textFont(segFont);
  textSize(32);
  textAlign(CENTER, CENTER);

  for (int i = 0; i < 8; i++) {
    float bx = i * (boxW + spacing);
    noFill();

    if (matrixArray[i] == 1) {
      stroke(255, 255, 0, 200);
      strokeWeight(2);
      fill(255, 255, 0, 60);
    } else {
      stroke(darkGreen, 120);
      strokeWeight(1);
      fill(darkGreen, 60);
    }

    text(i+1, bx + boxW/2, boxH/2);

    if (i == activeStep) {
      fill(neonGreen);
      text(i+1, bx + boxW/2, boxH/2);
      fill(neonGreen, 40);
      text(i+1, bx + boxW/2, boxH/2);
      fill(neonGreen);
      noStroke();
      rect(bx, boxH + 5, boxW, 5);
    }
  }
  textFont(font);
  textAlign(LEFT);
}

void drawRealAudioScope(float w, float h) {
  pushMatrix();
  translate(0, 20);

  float leftBarH = map(proxLeft, 0, 100, 0, h);
  float rightBarH = map(proxRight, 0, 100, 0, h);

  float sum = (leftBarH + rightBarH) / 2;

  noFill();
  stroke(brightGreen);
  strokeWeight(2);
  beginShape();

  int resolution = 200;
  for (int i = 0; i < resolution; i++) {
    float x = map(i, 0, resolution, 0, w);

    float waveOffset = sin(i * 0.2 + (frameCount * 0.1));


    float y = (h / 2) + (waveOffset * (sum * 0.4));

    vertex(x, y);
  }
  endShape();

  popMatrix();
}

void triggerSound() {
  float avgProx = (proxLeft + proxRight) / 2.0;

  float freq = map(avgProx, 0, 100, 110, 880);
  wave.setFrequency(freq);

  float vol = map(avgProx, 0, 100, 0.05, 0.5);

  wave.setAmplitude(vol);
  audioPulseTimer = 5;
}

void addLog(String message) {
  String timestamp = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
  systemLogs.append(timestamp + ": " + message);
}
