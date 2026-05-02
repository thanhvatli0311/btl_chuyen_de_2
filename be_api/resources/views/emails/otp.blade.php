{{-- resources/views/emails/otp.blade.php --}}
<!DOCTYPE html>
<html>
<head>
    <style>
        .container { font-family: sans-serif; padding: 20px; border: 1px solid #ddd; border-radius: 10px; }
        .otp { font-size: 32px; font-weight: bold; color: #0047AB; letter-spacing: 5px; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h2>Mã xác thực OTP</h2>
        <p>Chào bạn, mã xác thực để đổi mật khẩu tại <b>Phone Market</b> của bạn là:</p>
        <div class="otp">{{ $otp }}</div>
        <p>Mã này có hiệu lực trong <b>10 phút</b>. Đừng cho ai biết mã này nhé!</p>
    </div>
</body>
</html>