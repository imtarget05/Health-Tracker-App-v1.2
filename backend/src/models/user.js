// user.js
const userSchema = new mongoose.Schema({
  fullName: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
  },
  password: {
    type: String,
    // Không required cho user Firebase
  },
  profilePic: {
    type: String,
    default: "",
  },
  firebaseUID: {
    type: String,
    unique: true,
    sparse: true // Cho phép null
  },
  authProvider: {
    type: String,
    enum: ['email', 'firebase'],
    default: 'email'
  }
}, {
  timestamps: true,
});