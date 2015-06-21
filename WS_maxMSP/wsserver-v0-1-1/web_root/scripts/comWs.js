var gConnection; // websocket gConnection


function ws_connect() {
	
    if ('WebSocket' in window) {


/// crée la connection ///

        writeToScreen('Connecting');
        gConnection = new WebSocket('ws://' + window.location.host + '/maxmsp');

	    gConnection.onopen = function(ev) {
        
            connectButton.label = "WebSocket Disconnect";
//            document.getElementById("update").disabled=false;
//            document.getElementById("update").innerHTML = "Disable Update";
            writeToScreen('CONNECTED');
            var message = 'update on';
            writeToScreen('SENT: ' + message);
            gConnection.send(message);
        };

        gConnection.onclose = function(ev) {
//            document.getElementById("update").disabled=true;
//            document.getElementById("update").innerHTML = "Enable Update";
            connectButton.label = "WebSocket Connect";
            writeToScreen('DISCONNECTED');
        };


  		 gConnection.onerror = function(ev) {
            alert("WebSocket error");
        };



// recoit de max (donc des autres utilisateur si max redirige) //

        gConnection.onmessage = function(ev) {
          //TODO: handle messages
	writeToScreen('RECEIVEDE: ' + ev.data);
          if(ev.data.substr(0, 3) == "rx ")
          {
            json = ev.data.substr(3);
            
            if(json.substr(0, 5) == "move ")
            {
              values = JSON.parse(json.substr(5));
              xypad.children[0].x = values.x * xypad._width();
              xypad.children[0].y = values.y * xypad._height();
              //console.log(xypad.children[0]);
              xypad.refresh();
			  socket.emit('message', 'values.x'); //osclocal
            }
			
			 if(json.substr(0, 4) == "btap")
            {
				var processingInstance;	 
				   if (!processingInstance) processingInstance = Processing.getInstanceById('pjs');
					 processingInstance.change();
			}
			
			
			
			 if(json.substr(0, 4) == "play") document.getElementById('player').play();
			 if(json.substr(0, 4) == "stop") document.getElementById('player').pause();
            
			 if(json.substr(0, 5) == "seek ")
            {	
			 values = JSON.parse(json.substr(5));
			 document.getElementById('player').currentTime = values.x;
			}
			
          }
          
          
        };

		
    

    } else {
        alert("WebSocket is not available!!!\n" +
              "Demo will not function.");
    }
}




// user connect/disconnect
function toggleConnection() {
    if (connectButton.label == "WebSocket Connect") {
      ws_connect();

    }
    else {
      gConnection.close();

    }
}
//
//// user turn updates on/off
//function toggleUpdate(el) {
//    var tag=el.innerHTML;
//    var message;
//    if (tag == "Enable Update") {
//        message = 'update on';
//        el.innerHTML = "Disable Update";
//    }
//    else {
//        message = 'update off';
//        el.innerHTML = "Enable Update";
//    }
//    writeToScreen('SENT: ' + message);
//    gConnection.send(message);
//}


function timeur(){
var timerRegulier = setInterval(function () {myTimer()}, 1000);
function myTimer() {
    var d = new Date();
    document.getElementById("demo").innerHTML = d.toLocaleTimeString();
}
//clearInterval(timerRegulier)
	
//var timerUncoup=setTimeout(function(){alert('Hello')},3000); //juste attent
//clearTimeout(timerUncoup);
}


