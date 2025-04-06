import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function validateUSN(usn: string): boolean {
  const usnRegex = /^1ms\d{2}[a-z]{2}\d{3}$/i;
  return usnRegex.test(usn);
}

export function validateEmail(email: string, usn: string): boolean {
  const emailRegex = new RegExp(`^${usn}@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$`, 'i');
  return emailRegex.test(email);
}

export function getYearFromUSN(usn: string): string {
  return `20${usn.substring(4, 6)}`;
}