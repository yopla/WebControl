
int value = 0;

void draw() {
  fill(value);
  rect(25, 25, 50, 50);
}

void mousePressed() {
change();
  gConnection.send('ljhhbhké');
	socket.emit('message', '/proc');
}

void change(){
  if(value == 0) {
    value = 255;
  } else {
    value = 0;
  }
}
