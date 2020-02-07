class SignalingChannel extends WebSocket {
    send(m){
	super.send(JSON.stringify(m));
    }

}


// const ws = new WebSocket('ws://localhost:3000/channel');



$(function(){
    var selfView  = document.getElementById('localVideo');
    var remoteView = document.getElementById('remoteVideo');

    navigator.mediaDevices.getUserMedia({ video: true })
	.then(mediaStream => {
	    localStream = mediaStream;
	    var tracks = localStream.getTracks();
	    console.log(tracks)
	}).catch(e => console.log(e));
    

    
    const signaling = new SignalingChannel('ws://localhost:3000/channel');
    const constraints = {video: true};

    const configuration = {iceServers: [{urls: 'stun:stun.l.google.com:19302'}]};

    const pc = new RTCPeerConnection(configuration);

    // send any ice candidates to the other peer
    pc.onicecandidate = ({candidate}) => signaling.send({candidate});

    // let the "negotiationneeded" event trigger offer generation
    pc.onnegotiationneeded = async () => {
	try {
	    await pc.setLocalDescription(await pc.createOffer());
	    // send the offer to the other peer
	    signaling.send({desc: pc.localDescription});
	} catch (err) {
	    console.error(err);
	}
    };

    // once remote track media arrives, show it in remote video element
    pc.ontrack = (event) => {
	// don't set srcObject again if it is already set.
	if (remoteView.srcObject) return;
	remoteView.srcObject = event.streams[0];
    };

    // call start() to initiate
    var status = "";
    async function start() {
	try {
	    // get local stream, show it in self-view and add it to be sent
	    const stream = await navigator.mediaDevices.getUserMedia(constraints);
	    status = "offering";
	    stream.getTracks().forEach((track) => pc.addTrack(track, stream));
	    selfView.srcObject = stream;
	    
	} catch (err) {
	    console.error(err);
	}
    }

    // signaling.onmessage = async ({desc, candidate}) => {
    var errCount = 0;
    
    signaling.onmessage = async (message) => {
	if (errCount > 4) { return }
	
	message = JSON.parse(message.data);
	console.log(message);

	var desc = message.desc;
	var candidate = message.candidate;
	
	try {
	    if (desc) {
		// if we get an offer, we need to reply with an answer
		if (desc.type === 'offer' && status !== 'offering') {
		    console.log('received offer');
		    console.log(status)
		    status = "answering";
		    await pc.setRemoteDescription(desc);
		    const stream = await navigator.mediaDevices.getUserMedia(constraints);

		    stream.getTracks().forEach((track) => pc.addTrack(track, stream));
		    await pc.setLocalDescription(await pc.createAnswer());
		    signaling.send({desc: pc.localDescription});
		} else if (desc.type === 'answer' && status !== 'answering') {
		    console.log('received answer');
		    try {
			await pc.setRemoteDescription(desc);
		    } catch(e) { console.log(e) }
		} else {
		    console.log('no action', desc.type, status);
		}
	    } else if (candidate) {
		await pc.addIceCandidate(candidate);
	    }
	} catch (err) {
	    console.error(errCount);
	    console.error(err);
	    // errCount++;
	}
    };

    $('#startButton').on('click', start);
})
