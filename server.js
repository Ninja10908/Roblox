const WebSocket = require('ws');
const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

// CHANGE THIS TO YOUR OWN SECRET TOKEN!
const AUTH_TOKEN = "MySecretToken123!@#";

const offers = [];
const clients = new Map();

app.get('/', (req, res) => {
    res.send('✅ Pet Trading Server Running!');
});

const server = app.listen(port, () => {
    console.log(`✅ Server running on port ${port}`);
});

const wss = new WebSocket.Server({ server });

function broadcastOffers() {
    const message = JSON.stringify({ type: 'offers', data: offers });
    clients.forEach((client, ws) => {
        if (client.authenticated && ws.readyState === WebSocket.OPEN) {
            ws.send(message);
        }
    });
}

wss.on('connection', (ws) => {
    console.log('🔗 New client connected');
    clients.set(ws, { authenticated: false, playerName: 'Unknown' });

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            const clientData = clients.get(ws);
            
            console.log('📩 Received:', data.type);
            
            if (data.type === 'auth') {
                if (data.token === AUTH_TOKEN) {
                    clientData.authenticated = true;
                    ws.send(JSON.stringify({ type: 'auth_ok' }));
                    ws.send(JSON.stringify({ type: 'offers', data: offers }));
                    console.log('✅ Client authenticated');
                } else {
                    ws.send(JSON.stringify({ type: 'error', message: 'Invalid token' }));
                }
            }
            else if (data.type === 'identify') {
                if (clientData.authenticated && data.data) {
                    clientData.playerName = data.data.playerName || 'Unknown';
                    console.log(`👤 Client: ${clientData.playerName}`);
                }
            }
            else if (data.type === 'new_offer') {
                if (clientData.authenticated && data.data) {
                    const newOffer = {
                        ...data.data,
                        timestamp: Date.now(),
                        playerDisplayName: clientData.playerName || data.data.playerName
                    };
                    offers.push(newOffer);
                    if (offers.length > 100) offers.shift();
                    console.log(`📊 New offer: ${newOffer.petName}`);
                    broadcastOffers();
                }
            }
            else if (data.type === 'heartbeat') {
                ws.send(JSON.stringify({ type: 'pong' }));
            }
        } catch (error) {
            console.error('❌ Error:', error);
        }
    });

    ws.on('close', () => {
        clients.delete(ws);
        console.log('🔌 Client disconnected');
    });
});

console.log('🎯 Server ready!');
