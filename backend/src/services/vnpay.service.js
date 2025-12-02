import qs from "qs";
import crypto from "crypto";
import vnpConfig from "../config/vnpay.config.js";

const sortObject = (obj) => {
    return Object.keys(obj)
        .sort()
        .reduce((result, key) => {
            result[key] = obj[key];
            return result;
        }, {});
};

export const createPaymentUrl = (orderId, amount, ipAddr) => {
    const date = new Date();
    const createDate = date.toISOString().replace(/[-:TZ.]/g, "").slice(0, 14);

    let vnp_Params = {
        vnp_Version: "2.1.0",
        vnp_Command: "pay",
        vnp_TmnCode: vnpConfig.vnp_TmnCode,
        vnp_Amount: amount * 100,
        vnp_CreateDate: createDate,
        vnp_CurrCode: "VND",
        vnp_IpAddr: ipAddr,
        vnp_Locale: "vn",
        vnp_OrderInfo: `Upgrade Pro for ${orderId}`,
        vnp_OrderType: "other",
        vnp_ReturnUrl: vnpConfig.vnp_ReturnUrl,
        vnp_TxnRef: orderId,
    };

    vnp_Params = sortObject(vnp_Params);

    const signData = qs.stringify(vnp_Params, { encode: false });
    const hmac = crypto.createHmac("sha512", vnpConfig.vnp_HashSecret);
    const signed = hmac.update(Buffer.from(signData, "utf-8")).digest("hex");

    return `${vnpConfig.vnp_Url}?${signData}&vnp_SecureHash=${signed}`;
};

export const verifyIpn = (query) => {
    const secureHash = query.vnp_SecureHash;

    delete query.vnp_SecureHash;
    delete query.vnp_SecureHashType;

    const sorted = sortObject(query);
    const signData = qs.stringify(sorted, { encode: false });

    const hmac = crypto.createHmac("sha512", vnpConfig.vnp_HashSecret);
    const checkHash = hmac.update(Buffer.from(signData, "utf-8")).digest("hex");

    return secureHash === checkHash;
};
