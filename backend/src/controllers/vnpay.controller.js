import { createPaymentUrl, verifyIpn } from "../services/vnpay.service.js";

export const createPayment = async (req, res) => {
    try {
        const { userId } = req.query;
        const amount = 99000; // tiền gói Pro
        const ipAddr = req.ip;

        const paymentUrl = createPaymentUrl(userId, amount, ipAddr);

        return res.json({
            status: "success",
            paymentUrl,
        });
    } catch (error) {
        console.error("createPayment error:", error);
        return res.status(500).json({ message: "Error creating payment" });
    }
};

export const vnpIpn = async (req, res) => {
    try {
        const isValid = verifyIpn({ ...req.query });

        if (!isValid) {
            return res.status(200).json({
                RspCode: "97",
                Message: "Invalid signature",
            });
        }

        if (req.query.vnp_ResponseCode === "00") {
            console.log("✅ Payment success for:", req.query.vnp_TxnRef);
            // TODO: update user → Pro trong Firebase
        }

        return res.status(200).json({
            RspCode: "00",
            Message: "Confirm Success",
        });
    } catch (error) {
        console.error("vnpIpn error:", error);
        return res.status(500).json({ message: "IPN error" });
    }
};
