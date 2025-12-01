export const NotificationType = {
  WATER_REMINDER: "water_reminder",
  MEAL_REMINDER: "meal_reminder",
  WORKOUT_REMINDER: "workout_reminder",
  CALORIE_OVER: "calorie_over",
  CALORIE_UNDER: "calorie_under",
  AI_PROCESSING_SUCCESS: "ai_processing_success",
  AI_PROCESSING_FAILURE: "ai_processing_failure",
  DAILY_SUMMARY: "daily_summary",
  GOAL_ACHIEVED: "goal_achieved",
  STREAK_REMINDER: "streak_reminder",
  RE_ENGAGEMENT: "re_engagement",
};

export const NotificationTemplates = {
  // 1. Water Reminder
  [NotificationType.WATER_REMINDER]: {
    title: "Uống nước thôi nào 💧",
    body:
      "Đã {{hours_since_last}} tiếng rồi chưa uống nước. " +
      "Hôm nay bạn mới uống {{current_water}}/{{target_water}} ml. " +
      "Nạp thêm ~{{suggested_ml}}ml để da đẹp dáng xinh nhé!",
  },

  // 2. Meal Reminder
  [NotificationType.MEAL_REMINDER]: {
    title: "Đến giờ ăn rồi 🍽",
    body:
      "Đừng quên chụp ảnh hoặc log bữa {{meal_type}} để AI tính calo giúp bạn nhé! 📸",
  },

  // 3. Workout Reminder
  [NotificationType.WORKOUT_REMINDER]: {
    title: "Đứng dậy vận động nào! 🏃‍♂️",
    body:
      "Hôm nay bạn mới đốt {{calories_burned}}/{{target_calories_burned}} kcal. " +
      "Làm vài động tác Squat hoặc đi bộ 15 phút nhé!",
  },

  // 4. Calorie Over
  [NotificationType.CALORIE_OVER]: {
    title: "Cảnh báo calo vượt mức ⚠️",
    body:
      "Oops! Hôm nay bạn đã nạp {{current_calories}}/{{target_calories}} kcal " +
      "({{percent}}% mục tiêu). Bữa tới hãy ăn nhẹ hoặc vận động thêm nhé.",
  },

  // 5. Calorie Under (thiếu nhiều)
  [NotificationType.CALORIE_UNDER]: {
    title: "Thiếu năng lượng rồi ⚠️",
    body:
      "Đã {{time}} rồi mà bạn mới ăn {{current_calories}}/{{target_calories}} kcal " +
      "({{percent}}% mục tiêu). Đừng để cơ thể bị thiếu năng lượng nhé.",
  },

  // 6. AI Processing Success
  [NotificationType.AI_PROCESSING_SUCCESS]: {
    title: "AI đã phân tích xong bữa ăn 🍜",
    body:
      "Bữa {{meal_type}} của bạn: {{food_name}} (~{{calories}} kcal). " +
      "Bấm để xem chi tiết và xác nhận.",
  },

  // 7. AI Processing Failure
  [NotificationType.AI_PROCESSING_FAILURE]: {
    title: "AI chưa nhận diện được món ăn 😢",
    body: "Không thể nhận diện món ăn trong ảnh. Thử chụp lại hoặc nhập thủ công nhé.",
  },

  // 8. Daily Summary
  [NotificationType.DAILY_SUMMARY]: {
    title: "Tổng kết hôm nay 🎯",
    body:
      "Hôm nay bạn đã ăn {{total_calories}}/{{target_calories}} kcal " +
      "và uống {{total_water}}/{{target_water}} ml nước. {{summary_note}}",
  },

  // 9. Goal Achieved
  [NotificationType.GOAL_ACHIEVED]: {
    title: "Chúc mừng! Bạn đã hoàn thành mục tiêu 🎉",
    body:
      "Hôm nay bạn đã đạt mục tiêu {{goal_type}}: {{current}}/{{target}}. " +
      "Huy hiệu '{{badge_name}}' đang chờ bạn!",
  },

  // 10. Streak Reminder
  [NotificationType.STREAK_REMINDER]: {
    title: "Đừng để mất streak nhé 🔥",
    body:
      "Bạn đã giữ streak {{streak_days}} ngày rồi. " +
      "Hôm nay vẫn chưa log gì, vào app 1 chút để giữ streak nhé!",
  },

  // 11. Re-engagement
  [NotificationType.RE_ENGAGEMENT]: {
    title: "Chúng tôi nhớ bạn 💙",
    body:
      "Đã {{inactive_days}} ngày bạn chưa mở app. " +
      "Quay lại cập nhật cân nặng và xem tiến độ nhé!",
  },
};
