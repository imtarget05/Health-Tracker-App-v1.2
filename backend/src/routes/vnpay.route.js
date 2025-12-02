import express from "express";
import { createPayment, vnpIpn } from "../controllers/vnpay.controller.js";

const router = express.Router();

router.get("/create", createPayment);
router.get("/ipn", vnpIpn);

export default router;
