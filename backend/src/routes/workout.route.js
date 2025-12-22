import express from "express";
import { protectRoute } from "../middleware/auth.middleware.js";
import { createWorkout } from "../controllers/workout.controller.js";

const router = express.Router();

// POST /workouts - create a workout entry
router.post("/", protectRoute, createWorkout);

export default router;
