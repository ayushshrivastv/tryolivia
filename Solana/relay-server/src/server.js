const express = require('express');
const WebSocket = require('ws');
const cors = require('cors');
const cron = require('node-cron');
const { Connection, PublicKey, Keypair } = require('@solana/web3.js');
const { Program, AnchorProvider, Wallet } = require('@coral-xyz/anchor');
require('dotenv').config();

class OliviaRelayServer {
    constructor() {
        this.app = express();
        this.port = process.env.PORT || 3000;
        this.solanaConnection = new Connection(process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com');
        this.relayKeypair = this.loadRelayKeypair();
        this.programId = new PublicKey(process.env.DAO_PROGRAM_ID || 'BQcHvNqgAT7TQonNJR6zoxu7eNCy9c7mB44K9CVaUcA');
        
        // Relay node metrics
        this.metrics = {
            messagesRelayed: 0,
            successfulDeliveries: 0,
            startTime: Date.now(),
            lastHeartbeat: Date.now(),
            connectedClients: 0,
            averageLatency: 0,
            uptimePercentage: 100
        };

        // Connected clients (WebSocket connections)
        this.clients = new Map();
        
        // Message queue for delivery
        this.messageQueue = [];
        
        this.setupExpress();
        this.setupWebSocket();
        this.setupCronJobs();
        this.registerWithDAO();
    }

    loadRelayKeypair() {
        if (process.env.RELAY_PRIVATE_KEY) {
            const privateKeyArray = JSON.parse(process.env.RELAY_PRIVATE_KEY);
            return Keypair.fromSecretKey(new Uint8Array(privateKeyArray));
        } else {
            console.log('⚠️  No private key found, generating new keypair');
            const keypair = Keypair.generate();
            console.log('🔑 New keypair generated:', keypair.publicKey.toString());
            console.log('💾 Save this private key to .env file:');
            console.log('RELAY_PRIVATE_KEY=' + JSON.stringify(Array.from(keypair.secretKey)));
            return keypair;
        }
    }

    setupExpress() {
        this.app.use(cors());
        this.app.use(express.json());

        // Health check endpoint
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                uptime: Date.now() - this.metrics.startTime,
                metrics: this.metrics,
                publicKey: this.relayKeypair.publicKey.toString()
            });
        });

        // Metrics endpoint
        this.app.get('/metrics', (req, res) => {
            res.json({
                ...this.metrics,
                uptime: Date.now() - this.metrics.startTime,
                publicKey: this.relayKeypair.publicKey.toString()
            });
        });

        // Message relay endpoint (HTTP fallback)
        this.app.post('/relay', async (req, res) => {
            try {
                const { recipient, encryptedContent, messageHash } = req.body;
                
                if (!recipient || !encryptedContent || !messageHash) {
                    return res.status(400).json({ error: 'Missing required fields' });
                }

                const success = await this.relayMessage(recipient, encryptedContent, messageHash);
                
                if (success) {
                    this.metrics.messagesRelayed++;
                    this.metrics.successfulDeliveries++;
                    res.json({ success: true, relayedBy: this.relayKeypair.publicKey.toString() });
                } else {
                    res.status(500).json({ error: 'Failed to relay message' });
                }
            } catch (error) {
                console.error('❌ Relay error:', error);
                res.status(500).json({ error: error.message });
            }
        });
    }

    setupWebSocket() {
        this.wss = new WebSocket.Server({ port: this.port + 1 });
        
        this.wss.on('connection', (ws, req) => {
            const clientId = this.generateClientId();
            this.clients.set(clientId, ws);
            this.metrics.connectedClients = this.clients.size;
            
            console.log(`🔗 Client connected: ${clientId} (${this.metrics.connectedClients} total)`);

            ws.on('message', async (data) => {
                try {
                    const message = JSON.parse(data.toString());
                    await this.handleWebSocketMessage(clientId, message);
                } catch (error) {
                    console.error('❌ WebSocket message error:', error);
                    ws.send(JSON.stringify({ error: error.message }));
                }
            });

            ws.on('close', () => {
                this.clients.delete(clientId);
                this.metrics.connectedClients = this.clients.size;
                console.log(`🔌 Client disconnected: ${clientId} (${this.metrics.connectedClients} remaining)`);
            });

            ws.on('error', (error) => {
                console.error('❌ WebSocket error:', error);
                this.clients.delete(clientId);
                this.metrics.connectedClients = this.clients.size;
            });

            // Send welcome message
            ws.send(JSON.stringify({
                type: 'welcome',
                relayId: this.relayKeypair.publicKey.toString(),
                clientId: clientId
            }));
        });

        console.log(`🌐 WebSocket server listening on port ${this.port + 1}`);
    }

    async handleWebSocketMessage(clientId, message) {
        const startTime = Date.now();
        
        switch (message.type) {
            case 'relay_message':
                const success = await this.relayMessage(
                    message.recipient, 
                    message.encryptedContent, 
                    message.messageHash
                );
                
                const client = this.clients.get(clientId);
                if (client) {
                    client.send(JSON.stringify({
                        type: 'relay_response',
                        messageHash: message.messageHash,
                        success: success,
                        relayedBy: this.relayKeypair.publicKey.toString()
                    }));
                }

                if (success) {
                    this.metrics.messagesRelayed++;
                    this.metrics.successfulDeliveries++;
                }
                break;

            case 'ping':
                const client2 = this.clients.get(clientId);
                if (client2) {
                    client2.send(JSON.stringify({ type: 'pong' }));
                }
                break;

            default:
                console.log('❓ Unknown message type:', message.type);
        }

        // Update latency metrics
        const latency = Date.now() - startTime;
        this.updateLatencyMetrics(latency);
    }

    async relayMessage(recipient, encryptedContent, messageHash) {
        try {
            // Find the recipient in connected clients
            const recipientClient = Array.from(this.clients.values()).find(client => {
                // In a real implementation, you'd match by wallet address
                return client.readyState === WebSocket.OPEN;
            });

            if (recipientClient) {
                // Direct delivery to connected client
                recipientClient.send(JSON.stringify({
                    type: 'incoming_message',
                    encryptedContent: encryptedContent,
                    messageHash: messageHash,
                    relayedBy: this.relayKeypair.publicKey.toString()
                }));
                
                console.log(`📨 Message relayed directly: ${messageHash.substring(0, 8)}...`);
                return true;
            } else {
                // Queue for later delivery
                this.messageQueue.push({
                    recipient,
                    encryptedContent,
                    messageHash,
                    timestamp: Date.now()
                });
                
                console.log(`📥 Message queued for ${recipient}: ${messageHash.substring(0, 8)}...`);
                return true;
            }
        } catch (error) {
            console.error('❌ Relay message error:', error);
            return false;
        }
    }

    setupCronJobs() {
        // Update performance metrics every minute
        cron.schedule('* * * * *', () => {
            this.updatePerformanceMetrics();
        });

        // Report to DAO every 5 minutes
        cron.schedule('*/5 * * * *', () => {
            this.reportToDAO();
        });

        // Clean old queued messages every hour
        cron.schedule('0 * * * *', () => {
            this.cleanMessageQueue();
        });

        console.log('⏰ Cron jobs scheduled');
    }

    updatePerformanceMetrics() {
        const uptime = Date.now() - this.metrics.startTime;
        this.metrics.uptimePercentage = Math.min(100, (uptime / (uptime + 1000)) * 100); // Simplified calculation
        this.metrics.lastHeartbeat = Date.now();
        
        console.log(`📊 Metrics updated - Messages: ${this.metrics.messagesRelayed}, Clients: ${this.metrics.connectedClients}, Uptime: ${this.metrics.uptimePercentage.toFixed(1)}%`);
    }

    async reportToDAO() {
        try {
            // In a real implementation, this would call the Solana program
            console.log('📡 Reporting performance to DAO...');
            
            // Mock DAO reporting
            const report = {
                relayId: this.relayKeypair.publicKey.toString(),
                messagesRelayed: this.metrics.messagesRelayed,
                uptimePercentage: this.metrics.uptimePercentage,
                averageLatency: this.metrics.averageLatency,
                timestamp: Date.now()
            };

            console.log('📈 Performance report:', report);
            
            // Reset counters for next period
            this.metrics.messagesRelayed = 0;
            
        } catch (error) {
            console.error('❌ Failed to report to DAO:', error);
        }
    }

    cleanMessageQueue() {
        const oneHourAgo = Date.now() - (60 * 60 * 1000);
        const initialLength = this.messageQueue.length;
        
        this.messageQueue = this.messageQueue.filter(msg => msg.timestamp > oneHourAgo);
        
        const cleaned = initialLength - this.messageQueue.length;
        if (cleaned > 0) {
            console.log(`🧹 Cleaned ${cleaned} old messages from queue`);
        }
    }

    updateLatencyMetrics(latency) {
        if (this.metrics.averageLatency === 0) {
            this.metrics.averageLatency = latency;
        } else {
            this.metrics.averageLatency = (this.metrics.averageLatency * 0.9) + (latency * 0.1);
        }
    }

    generateClientId() {
        return Math.random().toString(36).substring(2, 15);
    }

    async registerWithDAO() {
        try {
            console.log('🏛️  Registering with OLIVIA DAO...');
            console.log('🔑 Relay Public Key:', this.relayKeypair.publicKey.toString());
            console.log('🌐 Endpoint: ws://localhost:' + (this.port + 1));
            
            // In a real implementation, this would call the register_relay_node instruction
            console.log('✅ Registration with DAO completed (mock)');
            
        } catch (error) {
            console.error('❌ Failed to register with DAO:', error);
        }
    }

    start() {
        this.app.listen(this.port, () => {
            console.log('🚀 OLIVIA Relay Server Started');
            console.log('📡 HTTP API:', `http://localhost:${this.port}`);
            console.log('🌐 WebSocket:', `ws://localhost:${this.port + 1}`);
            console.log('🔑 Public Key:', this.relayKeypair.publicKey.toString());
            console.log('💰 Ready to earn relay rewards!');
        });
    }
}

// Start the relay server
if (require.main === module) {
    const relayServer = new OliviaRelayServer();
    relayServer.start();
}

module.exports = OliviaRelayServer;
