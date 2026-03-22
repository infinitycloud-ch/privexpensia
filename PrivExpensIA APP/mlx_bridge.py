#!/usr/bin/env python3
"""
MLX Bridge for iOS - Qwen Model Inference
"""

import sys
import json
import os
from pathlib import Path

# Add MLX to path
sys.path.append('~/Library/Python/3.13/lib/python/site-packages')

from mlx_lm import load, generate

class QwenMLXBridge:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.model_path = Path.home() / "Documents/models/qwen2.5-0.5b-4bit"

    def load_model(self):
        """Load the Qwen model with MLX"""
        if not self.model:
            try:
                self.model, self.tokenizer = load(str(self.model_path))
                return {"success": True, "message": "Model loaded"}
            except Exception as e:
                return {"success": False, "error": str(e)}
        return {"success": True, "message": "Model already loaded"}

    def run_inference(self, prompt: str, max_tokens: int = 500):
        """Run inference on the prompt"""
        if not self.model:
            load_result = self.load_model()
            if not load_result["success"]:
                return load_result

        try:
            # Generate response
            response = generate(
                self.model,
                self.tokenizer,
                prompt=prompt,
                max_tokens=max_tokens
            )

            # Try to extract JSON from response
            json_data = None
            if '{' in response:
                json_start = response.index('{')
                json_end = response.rfind('}') + 1
                json_str = response[json_start:json_end]
                try:
                    json_data = json.loads(json_str)
                except:
                    pass

            return {
                "success": True,
                "response": response,
                "json_data": json_data
            }

        except Exception as e:
            return {"success": False, "error": str(e)}

def main():
    """Main entry point for command line usage"""
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command provided"}))
        sys.exit(1)

    command = sys.argv[1]
    bridge = QwenMLXBridge()

    if command == "load":
        result = bridge.load_model()
        print(json.dumps(result))

    elif command == "infer":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "No prompt provided"}))
            sys.exit(1)

        prompt = sys.argv[2]
        max_tokens = int(sys.argv[3]) if len(sys.argv) > 3 else 500

        result = bridge.run_inference(prompt, max_tokens)
        print(json.dumps(result, ensure_ascii=False))

    else:
        print(json.dumps({"error": f"Unknown command: {command}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()