import json
import os
import subprocess
import time
import unittest
import urllib.request
import urllib.error

class TestSettingsAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Determine paths
        cls.project_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        cls.executable_path = os.path.join(cls.project_dir, ".build", "debug", "MacSettingsController")
        
        # Build if not built
        print("Ensuring MacSettingsController is compiled...")
        subprocess.run(["swift", "build"], cwd=cls.project_dir, check=True)
        
        # Start the server as a background subprocess
        print("Starting MacSettingsController backend server...")
        cls.process = subprocess.Popen(
            [cls.executable_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=cls.project_dir
        )
        
        # Wait for the server to spin up
        time.sleep(1.5)
        
    @classmethod
    def tearDownClass(cls):
        print("Stopping MacSettingsController backend server...")
        cls.process.terminate()
        try:
            cls.process.wait(timeout=2.0)
        except subprocess.TimeoutExpired:
            cls.process.kill()
            cls.process.wait()
            
    def test_health_endpoint(self):
        url = "http://localhost:9090/health"
        req = urllib.request.Request(url)
        try:
            with urllib.request.urlopen(req, timeout=3.0) as response:
                self.assertEqual(response.status, 200)
                data = json.loads(response.read().decode('utf-8'))
                self.assertEqual(data.get("status"), "ok")
        except urllib.error.URLError as e:
            self.fail(f"Could not connect to server: {e}")

    def test_browsers_endpoint(self):
        url = "http://localhost:9090/browsers"
        req = urllib.request.Request(url)
        try:
            with urllib.request.urlopen(req, timeout=3.0) as response:
                self.assertEqual(response.status, 200)
                data = json.loads(response.read().decode('utf-8'))
                
                # Check structure
                self.assertIn("browsers", data)
                self.assertIn("defaultBrowser", data)
                
                browsers = data["browsers"]
                self.assertTrue(len(browsers) > 0, "Installed browsers list should not be empty")
                
                # Find Safari in the list
                safari_installed = any(b.get("bundleIdentifier") == "com.apple.Safari" for b in browsers)
                self.assertTrue(safari_installed, "Safari should be detected in the installed browsers list")
                
                # Verify defaultBrowser details
                default_browser = data["defaultBrowser"]
                self.assertIsNotNone(default_browser)
                self.assertIn("bundleIdentifier", default_browser)
                self.assertIn("name", default_browser)
        except urllib.error.URLError as e:
            self.fail(f"Could not connect to server: {e}")

    def test_set_default_endpoint(self):
        # First, query /browsers to get the current default browser identifier
        browsers_url = "http://localhost:9090/browsers"
        try:
            with urllib.request.urlopen(browsers_url, timeout=3.0) as response:
                data = json.loads(response.read().decode('utf-8'))
                current_default_id = data["defaultBrowser"]["bundleIdentifier"]
        except Exception as e:
            self.fail(f"Could not fetch current default browser: {e}")
            
        # Post a request to set the default browser to the current default
        # (This is safe because it registers the same browser, avoiding actual changes)
        url = "http://localhost:9090/set_default"
        payload = json.dumps({"bundleIdentifier": current_default_id}).encode('utf-8')
        req = urllib.request.Request(
            url, 
            data=payload, 
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        
        try:
            with urllib.request.urlopen(req, timeout=5.0) as response:
                self.assertEqual(response.status, 200)
                data = json.loads(response.read().decode('utf-8'))
                self.assertEqual(data.get("status"), "success")
        except urllib.error.HTTPError as e:
            body = e.read().decode('utf-8')
            self.fail(f"POST /set_default failed with HTTP {e.code}: {body}")
        except urllib.error.URLError as e:
            self.fail(f"Could not connect to server: {e}")

if __name__ == "__main__":
    unittest.main()
