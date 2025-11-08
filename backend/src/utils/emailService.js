import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
    service: 'Gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
    },
});

export const sendOTPEmail = async (email, otp, type = 'login') => {
    const subject = type === 'login'
        ? 'Mã OTP đăng nhập của bạn'
        : 'Mã OTP reset mật khẩu';

    const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2>Mã xác thực của bạn</h2>
      <p>Mã OTP: <strong style="font-size: 24px; color: #2563eb;">${otp}</strong></p>
      <p>Mã có hiệu lực trong ${type === 'login' ? '5 phút' : '10 phút'}.</p>
      <p><em>Lưu ý: Không chia sẻ mã này với bất kỳ ai.</em></p>
    </div>
  `;

    await transporter.sendMail({
        from: process.env.EMAIL_USER,
        to: email,
        subject,
        html,
    });
};

export const generateOTP = () => {
    // Generate 6-digit OTP
    return Math.floor(100000 + Math.random() * 900000).toString();
};