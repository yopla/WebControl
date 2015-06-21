void setup() {
  size(400, 300);
  background(255);
}
 
void touchMove(TouchEvent touchEvent) {
  // empty the canvas
  noStroke();
  fill(255);
  rect(0, 0, 400, 300);
 
  // draw circles at where fingers touch
  fill(180, 180, 100);
  for (int i = 0; i < touchEvent.touches.length; i++) {
    int x = touchEvent.touches[i].offsetX;
    int y = touchEvent.touches[i].offsetY;
    ellipse(x, y, 50, 50);
  }
}
 
void touchEnd(TouchEvent touchEvent) {
  noStroke();
  fill(255);
  rect(1, 1, 400, 300);
}
