import dotenv from "dotenv";
dotenv.config();

export default {
    vnp_TmnCode: process.env.VNP_TMN_CODE,
    vnp_HashSecret: process.env.VNP_HASH_SECRET,
    vnp_Url: process.env.VNP_URL,               // https://sandbox.vnpayment.vn/paymentv2/vpcpay.html
    vnp_ReturnUrl: process.env.VNP_RETURN_URL, // URL để user redirect sau thanh toán
    vnp_IpnUrl: process.env.VNP_IPN_URL        // URL server nhận callback
};
