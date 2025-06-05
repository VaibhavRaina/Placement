import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const connectDB = async (): Promise<void> => {
  try {
    const mongoURI = process.env.MONGODB_URI as string;

    await mongoose.connect(mongoURI);

    console.log('MongoDB Connected...');
  } catch (err: any) {
    console.error('MongoDB Connection Error:', err.message);
    console.log('Continuing without MongoDB connection...');
    // Don't exit process - allow health checks to work
  }
};

export default connectDB;