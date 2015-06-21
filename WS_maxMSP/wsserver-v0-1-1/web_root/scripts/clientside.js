var panel;
var connectButton;
var label;
var xypad;


function init() {  
   panel = new Interface.Panel({  
    background:"#fff", 
    stroke:"000",
    container:$("#panel"),
    useRelativeSizesAndPositions : true
 

  }); 
  
  connectButton = new Interface.Button({ 
    background:"#fff",
    bounds:[0.,0.,0.7,0.3 ],  
    label:'WebSocket Connect',    
    size:34,
    stroke:"000",
    style:'normal',
    onvaluechange: function() {
      this.clear();
      toggleConnection();
	  document.getElementById('player').play();
	  document.getElementById('player').pause();
    }
  });
  
  label = new Interface.Label({ 
    bounds:[0.51,0.,0.9, 0.05],
    value:'',
    hAlign:'left',
    vAlign:'middle',
    size:22,
    stroke:"000",
    style:'normal'
  });
  
  
  xypad = new Interface.XY({
    background:"#555",
    stroke:"000",
    childWidth: 40,
    numChildren: 1,
    bounds:[0,0.3,0.9,0.9],
    usePhysics : false,
    friction : 0.9,
    activeTouch : true,
    maxVelocity : 100,
    detectCollisions : true,
    onvaluechange : function() {
	
      if(gConnection) 
        gConnection.send('move '+JSON.stringify(this.values[0], function(key, val) {
                                              return val.toFixed ? Number(val.toFixed(2)) : val;
                                          })
										  
        );
    },
    oninit: function() { this.rainbow() }
  });
  
  panel.add(connectButton, label, xypad);

}

function writeToScreen (message) {
  label.clear();
  label.setValue(message);
}





