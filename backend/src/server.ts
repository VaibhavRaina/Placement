import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import connectDB from './config/db';

// Route imports
import authRoutes from './routes/authRoutes';
import noticeRoutes from './routes/noticeRoutes';
import studentRoutes from './routes/studentRoutes';

// Load env variables
dotenv.config();

// Connect to MongoDB
connectDB();

// Initialize express app
const app = express();

// Middleware
app.use(express.json());

// CORS configuration
const corsOptions = {
  origin: ['http://localhost:3000', 'http://localhost:5173'], // Both common development ports
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
};
app.use(cors(corsOptions));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/notices', noticeRoutes);
app.use('/api/students', studentRoutes);

// Basic route
app.get('/', (req: Request, res: Response) => {
  res.send('Placement Portal API is running');
});

// Health check endpoints for Kubernetes
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/ready', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ready', timestamp: new Date().toISOString() });
});

// Error handling middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Server Error',
    error: process.env.NODE_ENV === 'production' ? null : err.message,
  });
});

// Start server
const PORT = process.env.PORT || 8080;

app.listen(PORT, () => {
  console.log(`Server running in ${process.env.NODE_ENV} mode on port ${PORT}`);
});