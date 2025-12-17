import os
import json
import cv2
import numpy as np
from ultralytics import YOLO
import yaml
from typing import Dict, Any
import io
from PIL import Image
import logging
import torch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class FoodPredictor:
    def __init__(self, models_dir: str = "models"):
        self.models_dir = models_dir
        self.model = None
        self.nutrition_mapping = {}
        self.food_categories = []
        self.model_loaded = False

        self.conf_threshold = 0.25  
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        self._validate_model_files()
        self.load_model()
    
    def _validate_model_files(self) -> None:
        """Validate that all required model files exist"""
        required_files = {
            'model': 'best.pt',
            'nutrition_mapping': 'nutrition_mapping.json', 
            'config': 'data.yaml',
            'model_info': 'model_info.json'
        }
        
        missing_files = []
        for file_type, filename in required_files.items():
            file_path = os.path.join(self.models_dir, filename)
            if not os.path.exists(file_path):
                missing_files.append(f"{filename} ({file_type})")
        
        if missing_files:
            error_msg = f"Missing model files: {', '.join(missing_files)}"
            logger.error(error_msg)
            raise FileNotFoundError(error_msg)
        
        logger.info("All model files validated")
    
    def load_model(self) -> None:
        """Load YOLO model and nutrition data"""
        try:
            # Load YOLO model
            model_path = os.path.join(self.models_dir, "best.pt")
            self.model = YOLO(model_path)

            # Đưa model lên GPU nếu có
            self.model.to(self.device)
            logger.info(f"✅ YOLO model loaded on device: {self.device}")

            # Load dataset configuration (class names)
            config_path = os.path.join(self.models_dir, "data.yaml")
            with open(config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
                self.food_categories = config.get('names', [])
            logger.info(f"✅ Loaded {len(self.food_categories)} food categories")

            # Load nutrition mapping
            nutrition_path = os.path.join(self.models_dir, "nutrition_mapping.json")
            with open(nutrition_path, 'r', encoding='utf-8') as f:
                self.nutrition_mapping = json.load(f)
            logger.info(f"✅ Nutrition mapping loaded: {len(self.nutrition_mapping)} items")
            
            self.model_loaded = True
            logger.info("🎯 Food predictor fully initialized")
            
        except Exception as e:
            logger.error(f"❌ Failed to load model: {e}")
            self.model_loaded = False
            raise
    
    def estimate_portion(self, bbox_area: float, img_area: float) -> int:
        """Estimate portion size in grams based on bounding box area"""
        if img_area == 0:
            return 150
        
        relative_size = bbox_area / img_area
        base_portion = 200
        scaling_factor = 1.8
        estimated_portion = base_portion * relative_size * scaling_factor
        
        return max(80, min(600, int(estimated_portion)))
    
    def _calculate_nutrition(self, category: str, portion_g: int) -> Dict[str, float]:
        """Calculate nutrition values for a given food category and portion"""
        if category not in self.nutrition_mapping:
            return {
                'calories': 0.0, 'protein': 0.0, 'fat': 0.0, 
                'carbs': 0.0, 'fiber': 0.0, 'sugar': 0.0
            }
        
        info = self.nutrition_mapping[category]
        nutrition = {
            'calories': round((info.get('calories_per_100g', 0) / 100) * portion_g, 1),
            'protein': round((info.get('protein_per_100g', 0) / 100) * portion_g, 1),
            'fat': round((info.get('fat_per_100g', 0) / 100) * portion_g, 1),
            'carbs': round((info.get('carbs_per_100g', 0) / 100) * portion_g, 1),
            'fiber': round((info.get('fiber_per_100g', 0) / 100) * portion_g, 1),
            'sugar': round((info.get('sugar_per_100g', 0) / 100) * portion_g, 1)
        }
        
        return nutrition
    
    def analyze_image(self, image_bytes: bytes) -> Dict[str, Any]:
        """Analyze image and return detailed nutrition information"""
        if not self.model_loaded:
            return {
                'success': False,
                'error': 'Model not loaded',
                'detections': [],
                'total_nutrition': {},
                'items_count': 0
            }
        
        try:
            # Convert bytes to PIL image and ensure RGB
            image = Image.open(io.BytesIO(image_bytes))
            if image.mode != 'RGB':
                image = image.convert('RGB')

            image_array = np.array(image)
            image_array_bgr = cv2.cvtColor(image_array, cv2.COLOR_RGB2BGR)

            # Get image dimensions
            h, w = image_array.shape[:2]
            img_area = h * w

            # Multi-crop / multi-scale inference
            crops = []
            # full image
            crops.append({'img': image_array_bgr, 'offset': (0, 0)})

            # center crop 0.8
            def center_crop(arr, scale=0.8):
                hh, ww = arr.shape[:2]
                ch = int(hh * scale)
                cw = int(ww * scale)
                y0 = (hh - ch) // 2
                x0 = (ww - cw) // 2
                return arr[y0:y0+ch, x0:x0+cw], (x0, y0)

            for s in [0.9, 0.8, 0.7]:
                try:
                    cropped, (ox, oy) = center_crop(image_array_bgr, scale=s)
                    crops.append({'img': cropped, 'offset': (ox, oy), 'scale': s})
                except Exception:
                    pass

            all_detections = []

            for c in crops:
                try:
                    results = self.model(c['img'], conf=self.conf_threshold, verbose=False)
                except Exception as e:
                    logger.warning(f"Model inference failed on crop: {e}")
                    continue

                boxes = results[0].boxes
                logger.info(f"🔍 Raw boxes from YOLO (crop): {len(boxes)}")

                for box in boxes:
                    class_id = int(box.cls[0])
                    confidence = float(box.conf[0])
                    bbox = box.xyxy[0].cpu().numpy()

                    # If crop has offset, adjust box coordinates back to original image coords
                    ox, oy = c.get('offset', (0, 0))
                    if 'scale' in c:
                        s = c['scale']
                        # when cropping we used direct pixel coords, no scaling needed for offset adjust
                    bbox_adj = [bbox[0] + ox, bbox[1] + oy, bbox[2] + ox, bbox[3] + oy]

                    all_detections.append({
                        'class_id': class_id,
                        'confidence': confidence,
                        'bbox': bbox_adj,
                    })

            if len(all_detections) == 0:
                return {
                    'success': True,
                    'detections': [],
                    'total_nutrition': {
                        'calories': 0.0, 'protein': 0.0, 'fat': 0.0,
                        'carbs': 0.0, 'fiber': 0.0, 'sugar': 0.0
                    },
                    'items_count': 0,
                    'message': 'No food items detected'
                }

            # Simple aggregation: group detections by IoU & class, keep max confidence
            def iou(boxA, boxB):
                xA = max(boxA[0], boxB[0])
                yA = max(boxA[1], boxB[1])
                xB = min(boxA[2], boxB[2])
                yB = min(boxA[3], boxB[3])
                interW = max(0, xB - xA)
                interH = max(0, yB - yA)
                interArea = interW * interH
                boxAArea = max(0, (boxA[2] - boxA[0])) * max(0, (boxA[3] - boxA[1]))
                boxBArea = max(0, (boxB[2] - boxB[0])) * max(0, (boxB[3] - boxB[1]))
                union = boxAArea + boxBArea - interArea
                if union == 0:
                    return 0
                return interArea / union

            clusters = []
            for det in sorted(all_detections, key=lambda x: -x['confidence']):
                placed = False
                for cl in clusters:
                    # if same class and IoU > 0.3, merge
                    if cl['class_id'] == det['class_id'] and iou(cl['bbox'], det['bbox']) > 0.3:
                        # keep highest confidence and expand bbox
                        cl['confidence'] = max(cl['confidence'], det['confidence'])
                        # expand bbox to include both
                        cl['bbox'] = [
                            min(cl['bbox'][0], det['bbox'][0]),
                            min(cl['bbox'][1], det['bbox'][1]),
                            max(cl['bbox'][2], det['bbox'][2]),
                            max(cl['bbox'][3], det['bbox'][3])
                        ]
                        placed = True
                        break
                if not placed:
                    clusters.append({
                        'class_id': det['class_id'],
                        'confidence': det['confidence'],
                        'bbox': det['bbox']
                    })

            detections = []
            total_nutrition = {'calories': 0.0, 'protein': 0.0, 'fat': 0.0, 'carbs': 0.0, 'fiber': 0.0, 'sugar': 0.0}

            for cl in clusters:
                class_id = cl['class_id']
                confidence = cl['confidence']
                bbox = cl['bbox']

                bbox_w = bbox[2] - bbox[0]
                bbox_h = bbox[3] - bbox[1]
                bbox_area = max(0, bbox_w * bbox_h)

                category = self.food_categories[class_id]
                portion_g = self.estimate_portion(bbox_area, img_area)
                nutrition = self._calculate_nutrition(category, portion_g)

                for key in total_nutrition:
                    total_nutrition[key] += nutrition[key]

                detection_info = {
                    'food': category,
                    'confidence': round(confidence, 3),
                    'portion_g': portion_g,
                    'bbox': [float(coord) for coord in bbox],
                    'nutrition': nutrition
                }
                detections.append(detection_info)

            total_nutrition = {k: round(v, 1) for k, v in total_nutrition.items()}

            return {
                'success': True,
                'detections': detections,
                'total_nutrition': total_nutrition,
                'items_count': len(detections),
                'image_dimensions': {'width': w, 'height': h}
            }
            
        except Exception as e:
            logger.error(f"Image analysis error: {e}")
            return {
                'success': False,
                'error': f'Analysis failed: {str(e)}',
                'detections': [],
                'total_nutrition': {},
                'items_count': 0
            }
