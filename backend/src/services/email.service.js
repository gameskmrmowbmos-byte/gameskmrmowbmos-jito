const nodemailer = require('nodemailer');
const env = require('../config/env');
const logger = require('../utils/logger');

let transporter;

function configured() {
  return Boolean(env.smtp.host && env.smtp.user && env.smtp.pass);
}

function getTransporter() {
  if (!configured()) return null;
  transporter ??= nodemailer.createTransport({
    host: env.smtp.host,
    port: env.smtp.port,
    secure: env.smtp.secure,
    auth: { user: env.smtp.user, pass: env.smtp.pass },
  });
  return transporter;
}

async function sendPasswordResetEmail({ to, name, resetUrl }) {
  const mailer = getTransporter();
  if (!mailer) {
    logger.warn('SMTP is not configured; password reset email was not sent');
    return false;
  }
  try {
    await mailer.sendMail({
      from: env.smtp.from,
      to,
      subject: 'Reset your Matka Management Demo password',
      text:
        `Hello ${name},\n\nOpen this link within 30 minutes to reset your ` +
        `password:\n${resetUrl}\n\nIf you did not request this, ignore this email.`,
      html:
        `<p>Hello ${name},</p><p>Open the link below within 30 minutes to ` +
        `reset your password:</p><p><a href="${resetUrl}">Reset password</a></p>` +
        '<p>If you did not request this, ignore this email.</p>',
    });
    return true;
  } catch (error) {
    logger.error('Password reset email delivery failed', {
      message: error.message,
    });
    return false;
  }
}

module.exports = { configured, sendPasswordResetEmail };
