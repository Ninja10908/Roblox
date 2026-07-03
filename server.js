const WebSocket = require('ws');
const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

// 🔑 CHANGE THIS TO YOUR OWN SECRET TOKEN!
// Generate a secure token at: https://randomkeygen.com/
const AUTH_TOKEN = "MySecretToken123!@#";

// Store offers and clients in memory
const offers = [];
const clients = new Map();

// ============================================
// ✅ WEB ROUTES - Fixes the 404 error
// ============================================

// Home page - shows server status
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>🐾 Pet Trading Server</title>
            <style>
                body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #0d1117; color: #c9d1d9; }
                h1 { color: #58a6ff; }
                .status { background: #161b22; padding: 20px; border-radius: 10px; display: inline-block; }
                .online { color: #3fb950; }
                .info { color: #8b949e; }
            </style>
        </head>
        <body>
            <h1>🐾 Pet Trading Server</h1>
            <div class="status">
                <p>✅ Status: <span class="online">ONLINE</span></p>
                <p>📡 Connected Clients: <strong>${clients.size}</strong></p>
                <p>📊 Total Offers: <strong>${offers.length}</strong></p>
                <p class="info">🔗 WebSocket: wss://${req.get('host')}</p>
                <p class="info">🕐 Uptime: ${Math.floor(process.uptime())} seconds</p>
            </div>
        </body>
        </html>
    `);
});

// API status endpoint (JSON)
app.get('/status', (req, res) => {
    res.json({
        status: 'online',
        clients: clients.size,
        offers: offers.length,
        uptime: Math.floor(process.uptime())
    });
});

// ============================================
// 🚀 START SERVER
// ============================================

const server = app.listen(port, () => {
    console.log(`✅ Server running on port ${port}`);
    console.log(`🔗 WebSocket: ws://localhost:${port}`);
    console.log(`🌐 Web: http://localhost:${port}`);
});

// ============================================
// 🔌 WEBSOCKET SERVER
// ============================================

const wss = new WebSocket.Server({ server });

// Broadcast offers to all authenticated clients
function broadcastOffers() {
    const message = JSON.stringify({ type: 'offers', data: offers });
    clients.forEach((client, ws) => {
        if (client.authenticated && ws.readyState === WebSocket.OPEN) {
            try {
                ws.send(message);
            } catch (error) {
                console.error('❌ Broadcast error:', error);
            }
        }
    });
}

// Handle new WebSocket connections
wss.on('connection', (ws) => {
    console.log('🔗 New client connected');
    
    // Store client info
    clients.set(ws, {
        authenticated: false,
        playerName: 'Unknown',
        userId: 'Unknown'
    });

    // Handle incoming messages
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            const clientData = clients.get(ws);
            
            console.log(`📩 Received: ${data.type} from ${clientData.playerName || 'Unknown'}`);
            
            // ----- AUTHENTICATION -----
            if (data.type === 'auth') {
                if (data.token === AUTH_TOKEN) {
                    clientData.authenticated = true;
                    ws.send(JSON.stringify({
                        type: 'auth_ok',
                        message: '✅ Authentication successful'
                    }));
                    // Send existing offers immediately
                    ws.send(JSON.stringify({
                        type: 'offers',
                        data: offers
                    }));
                    console.log('✅ Client authenticated successfully');
                } else {
                    ws.send(JSON.stringify({
                        type: 'error',
                        message: '❌ Invalid authentication token'
                    }));
                    console.log('❌ Authentication failed - invalid token');
                }
            }
            
            // ----- IDENTIFY PLAYER -----
            else if (data.type === 'identify') {
                if (clientData.authenticated && data.data) {
                    clientData.playerName = data.data.playerName || 'Unknown';
                    clientData.userId = data.data.userId || 'Unknown';
                    console.log(`👤 Player identified: ${clientData.playerName} (${clientData.userId})`);
                }
            }
            
            // ----- NEW OFFER -----
            else if (data.type === 'new_offer') {
                if (clientData.authenticated && data.data) {
                    const newOffer = {
                        ...data.data,
                        timestamp: Date.now(),
                        playerDisplayName: clientData.playerName || data.data.playerName || 'Unknown'
                    };
                    
                    offers.push(newOffer);
                    
                    // Keep only last 100 offers
                    if (offers.length > 100) {
                        offers.splice(0, offers.length - 100);
                    }
                    
                    console.log(`📊 New offer: ${newOffer.petName} from ${newOffer.playerDisplayName}`);
                    
                    // Broadcast to all connected clients
                    broadcastOffers();
                }
            }
            
            // ----- HEARTBEAT -----
            else if (data.type === 'heartbeat') {
                ws.send(JSON.stringify({ type: 'pong' }));
            }
            
            // ----- UNKNOWN TYPE -----
            else {
                console.log(`⚠️ Unknown message type: ${data.type}`);
            }
            
        } catch (error) {
            console.error('❌ Error processing message:', error);
        }
    });

    // Handle disconnection
    ws.on('close', () => {
        const clientData = clients.get(ws);
        console.log(`🔌 Client disconnected: ${clientData?.playerName || 'Unknown'}`);
        clients.delete(ws);
    });

    // Handle errors
    ws.on('error', (error) => {
        console.error('❌ WebSocket error:', error);
        clients.delete(ws);
    });
});

// ============================================
// 💓 KEEP ALIVE - Heartbeat check
// ============================================

const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
            ws.terminate();
            return;
        }
        ws.isAlive = false;
        ws.ping();
    });
}, 30000);

// Clean up interval on server close
wss.on('close', () => {
    clearInterval(interval);
});

console.log('🎯 Server ready! Waiting for connections...');
console.log(`🔑 Auth token: ${AUTH_TOKEN}`);
