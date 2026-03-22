# 🔌 API Documentation - PrivExpensIA v2.0
## Receipt Extraction & Expense Management API

**Version**: 2.0.0  
**Base URL**: `https://api.privexpensia.com/v2`  
**Authentication**: Bearer Token (JWT)

---

## 🔐 Authentication

### POST /auth/login
**Description**: Authenticate user and receive access token

**Request Body**:
```json
{
  "email": "user@company.com",
  "password": "secure_password"
}
```

**Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 3600,
  "user": {
    "id": "usr_123456",
    "email": "user@company.com",
    "country": "CH",
    "language": "fr-CH"
  }
}
```

**Error Codes**:
- `401` - Invalid credentials
- `429` - Too many attempts
- `503` - Service unavailable

---

## 📸 Receipt Extraction

### POST /receipts/extract
**Description**: Extract data from receipt image using hybrid pipeline

**Headers**:
```
Authorization: Bearer {token}
Content-Type: multipart/form-data
```

**Request Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| image | file | Yes | Receipt image (JPEG, PNG, PDF) |
| mode | string | No | `fast`, `balanced`, `thorough` (default: `balanced`) |
| country | string | No | ISO country code (auto-detect if omitted) |
| enhance | boolean | No | Apply image enhancement (default: `false`) |

**Response** (200 OK):
```json
{
  "receipt_id": "rcpt_789abc",
  "status": "success",
  "confidence": 0.954,
  "extraction_method": "hybrid",
  "processing_time_ms": 450,
  "data": {
    "merchant": {
      "name": "Migros",
      "address": "Bahnhofstrasse 1, 8001 Zürich",
      "vat_number": "CHE-123.456.789"
    },
    "date": "2025-01-15",
    "time": "14:32",
    "items": [
      {
        "description": "Pain complet",
        "quantity": 2,
        "unit_price": 2.50,
        "total": 5.00,
        "vat_rate": 2.5
      },
      {
        "description": "Café moulu",
        "quantity": 1,
        "unit_price": 8.90,
        "total": 8.90,
        "vat_rate": 8.1
      }
    ],
    "amounts": {
      "subtotal": 13.90,
      "tax_breakdown": [
        {"rate": 2.5, "amount": 0.13, "base": 5.00},
        {"rate": 8.1, "amount": 0.72, "base": 8.90}
      ],
      "total": 14.75,
      "currency": "CHF"
    },
    "payment": {
      "method": "card",
      "last_four": "1234"
    },
    "category": "food",
    "metadata": {
      "receipt_number": "2025-0115-1432-001",
      "cashier": "023",
      "store_id": "M001"
    }
  },
  "confidence_breakdown": {
    "heuristic": 0.92,
    "ai": 0.89,
    "fusion": 0.954
  },
  "warnings": [],
  "image_quality": {
    "score": 0.85,
    "issues": []
  }
}
```

**Error Response** (400 Bad Request):
```json
{
  "error": {
    "code": "EXTRACTION_FAILED",
    "message": "Unable to extract receipt data",
    "details": {
      "reason": "Image too blurry",
      "confidence": 0.32,
      "suggestions": [
        "Retake photo with better lighting",
        "Ensure receipt is flat and in focus"
      ]
    }
  }
}
```

### GET /receipts/{receipt_id}
**Description**: Retrieve previously extracted receipt

**Response** (200 OK):
```json
{
  "receipt_id": "rcpt_789abc",
  "created_at": "2025-01-15T14:33:00Z",
  "updated_at": "2025-01-15T14:33:00Z",
  "data": { ... },
  "status": "verified",
  "user_corrections": []
}
```

### PUT /receipts/{receipt_id}
**Description**: Update/correct extracted data

**Request Body**:
```json
{
  "corrections": {
    "merchant.name": "Migros Langstrasse",
    "amounts.total": 14.80,
    "category": "business_meal"
  },
  "confidence_override": 1.0
}
```

### DELETE /receipts/{receipt_id}
**Description**: Delete receipt and associated data

---

## 📊 Analytics

### GET /analytics/summary
**Description**: Get expense summary statistics

**Query Parameters**:
- `start_date` - ISO date (YYYY-MM-DD)
- `end_date` - ISO date (YYYY-MM-DD)
- `group_by` - `day`, `week`, `month`, `category`
- `currency` - Convert to specific currency

**Response**:
```json
{
  "period": {
    "start": "2025-01-01",
    "end": "2025-01-31"
  },
  "summary": {
    "total_expenses": 3456.78,
    "receipt_count": 145,
    "average_expense": 23.84,
    "currency": "CHF"
  },
  "by_category": [
    {"category": "restaurant", "amount": 890.50, "count": 42},
    {"category": "transport", "amount": 567.30, "count": 28},
    {"category": "hotel", "amount": 1234.00, "count": 8}
  ],
  "by_vat": {
    "total_vat": 289.45,
    "recoverable": 245.67,
    "non_recoverable": 43.78
  }
}
```

### GET /analytics/trends
**Description**: Analyze spending trends

---

## 🌍 Batch Operations

### POST /batch/extract
**Description**: Process multiple receipts in batch

**Request**:
```json
{
  "images": [
    {"id": "img_001", "base64": "data:image/jpeg;base64,..."},
    {"id": "img_002", "base64": "data:image/jpeg;base64,..."}
  ],
  "mode": "fast",
  "parallel": 4
}
```

**Response**:
```json
{
  "batch_id": "batch_xyz123",
  "status": "processing",
  "total": 2,
  "completed": 0,
  "results": [],
  "estimated_completion": "2025-01-15T14:35:00Z"
}
```

### GET /batch/{batch_id}/status
**Description**: Check batch processing status

---

## 🎨 Configuration

### GET /config/categories
**Description**: Get available expense categories

**Response**:
```json
{
  "categories": [
    {"id": "food", "label": "Alimentation", "icon": "🍴"},
    {"id": "restaurant", "label": "Restaurant", "icon": "🍽️"},
    {"id": "transport", "label": "Transport", "icon": "🚗"},
    {"id": "hotel", "label": "Hôtel", "icon": "🏨"}
  ]
}
```

### GET /config/vat-rates/{country}
**Description**: Get VAT rates for specific country

**Response** (for CH):
```json
{
  "country": "CH",
  "rates": [
    {"rate": 8.1, "type": "standard", "categories": ["general"]},
    {"rate": 3.7, "type": "accommodation", "categories": ["hotel"]},
    {"rate": 2.5, "type": "reduced", "categories": ["food", "books"]}
  ],
  "rounding": 0.05,
  "inclusive_default": true
}
```

---

## 🔄 Webhooks

### POST /webhooks/configure
**Description**: Configure webhook endpoints

**Request**:
```json
{
  "events": ["receipt.extracted", "receipt.verified", "batch.completed"],
  "url": "https://your-server.com/webhook",
  "secret": "webhook_secret_key"
}
```

**Webhook Payload**:
```json
{
  "event": "receipt.extracted",
  "timestamp": "2025-01-15T14:33:00Z",
  "data": {
    "receipt_id": "rcpt_789abc",
    "confidence": 0.954,
    "category": "food"
  },
  "signature": "sha256=abcdef123456..."
}
```

---

## ⚠️ Error Codes

| Code | HTTP Status | Description | Action |
|------|-------------|-------------|--------|
| `AUTH_REQUIRED` | 401 | Missing or invalid token | Authenticate |
| `INSUFFICIENT_PERMISSIONS` | 403 | Lacks required permissions | Check user role |
| `RECEIPT_NOT_FOUND` | 404 | Receipt ID doesn't exist | Verify ID |
| `EXTRACTION_FAILED` | 400 | Cannot extract from image | Retry with better image |
| `IMAGE_TOO_LARGE` | 413 | Image exceeds 10MB | Compress image |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests | Wait and retry |
| `INVALID_COUNTRY` | 400 | Country not supported | Check supported countries |
| `INVALID_MODE` | 400 | Invalid extraction mode | Use fast/balanced/thorough |
| `BATCH_LIMIT_EXCEEDED` | 400 | Batch > 100 receipts | Split into smaller batches |
| `SERVICE_ERROR` | 500 | Internal server error | Contact support |

---

## 📊 Rate Limits

| Plan | Requests/min | Batch Size | Storage |
|------|--------------|------------|----------|
| Free | 10 | 5 | 100 receipts |
| Pro | 60 | 20 | 10,000 receipts |
| Business | 300 | 100 | Unlimited |
| Enterprise | Custom | Custom | Unlimited |

**Rate Limit Headers**:
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1642260000
```

---

## 🔧 SDK Examples

### JavaScript/TypeScript
```typescript
import { PrivExpensIA } from '@privexpensia/sdk';

const client = new PrivExpensIA({
  apiKey: 'your_api_key',
  mode: 'balanced'
});

const result = await client.extractReceipt(imageFile);
console.log(`Extracted ${result.merchant.name}: ${result.amounts.total}`);
```

### Python
```python
from privexpensia import Client

client = Client(api_key="your_api_key")
result = client.extract_receipt(
    image_path="receipt.jpg",
    mode="balanced"
)
print(f"Total: {result['amounts']['total']} {result['amounts']['currency']}")
```

### Swift (iOS)
```swift
import PrivExpensIA

let client = PrivExpensIA(apiKey: "your_api_key")
let result = try await client.extractReceipt(
    image: receiptImage,
    mode: .balanced
)
print("Merchant: \(result.merchant.name)")
```

### cURL
```bash
curl -X POST https://api.privexpensia.com/v2/receipts/extract \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "image=@receipt.jpg" \
  -F "mode=balanced"
```

---

## 📈 Changelog

### v2.0.0 (2025-01-15)
- 🆕 Hybrid extraction pipeline (heuristics + AI)
- 🆕 Qwen2.5 integration
- 🆕 95% accuracy achievement
- 🆕 Batch processing endpoints
- 🆕 Analytics dashboard API

### v1.5.0 (2024-12-01)
- Added 8 language support
- Improved VAT detection
- Category auto-mapping

### v1.0.0 (2024-10-15)
- Initial release
- Basic OCR extraction
- 5 country support

---

## 📞 Support

**API Status**: https://status.privexpensia.com  
**Documentation**: https://docs.privexpensia.com  
**Support Email**: api-support@privexpensia.com  
**Response Time**: < 4 hours (Business plan)

---

*API Documentation by DUPONT2 - PrivExpensIA Project*