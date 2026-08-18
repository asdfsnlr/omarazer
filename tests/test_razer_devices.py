import unittest
from unittest.mock import MagicMock
from scripts.helpers import (
    classify_device_type,
    parse_color,
    parse_speed,
    parse_direction,
    normalize_effect_name,
)
from scripts.devices import get_device_info

class TestRazerDevices(unittest.TestCase):
    def test_classify_device_type(self):
        self.assertEqual(classify_device_type("keyboard", "Razer BlackWidow"), "keyboard")
        self.assertEqual(classify_device_type("mouse", "Razer DeathAdder"), "mouse")
        self.assertEqual(classify_device_type("audio", "Razer Nommo Chroma"), "speaker")
        self.assertEqual(classify_device_type("audio", "Razer Kraken V3"), "headset")
        self.assertEqual(classify_device_type("mousemat", "Razer Goliathus"), "mousemat")
        self.assertEqual(classify_device_type("accessory", "Razer Base Station"), "accessory")

    def test_parse_color(self):
        self.assertEqual(parse_color("#ff0000"), (255, 0, 0))
        self.assertEqual(parse_color("00ff00"), (0, 255, 0))
        self.assertEqual(parse_color("0,0,255"), (0, 0, 255))
        with self.assertRaises(ValueError):
            parse_color("invalid")

    def test_parse_speed(self):
        self.assertEqual(parse_speed("fast"), 1)
        self.assertEqual(parse_speed("1"), 1)
        self.assertEqual(parse_speed("normal"), 2)
        self.assertEqual(parse_speed("medium"), 2)
        self.assertEqual(parse_speed("2"), 2)
        self.assertEqual(parse_speed("slow"), 3)
        self.assertEqual(parse_speed("3"), 3)
        self.assertEqual(parse_speed("very_slow"), 4)
        self.assertEqual(parse_speed("4"), 4)
        self.assertEqual(parse_speed(None, default=2), 2)
        self.assertEqual(parse_speed("invalid", default=2), 2)

    def test_parse_direction(self):
        self.assertEqual(parse_direction("left"), 2)
        self.assertEqual(parse_direction("right"), 1)

    def test_normalize_effect_name(self):
        self.assertEqual(normalize_effect_name("breath_single"), "breath_single")
        self.assertEqual(normalize_effect_name("breathing"), "breath_single")
        self.assertEqual(normalize_effect_name("spectrum-cycling"), "spectrum")

    def test_get_device_info(self):
        mock_dev = MagicMock()
        mock_dev.name = "Razer BlackWidow Chroma"
        mock_dev.type = "keyboard"
        mock_dev.serial = "XX123456"
        mock_dev.firmware_version = "v1.0"
        mock_dev.has = MagicMock(return_value=False)
        mock_dev.brightness = 100
        mock_dev.capabilities = {}
        mock_dev.fx = MagicMock()
        mock_dev.fx.advanced = False

        res = get_device_info(mock_dev)
        self.assertEqual(res["name"], "Razer BlackWidow Chroma")
        self.assertEqual(res["serial"], "XX123456")
        self.assertEqual(res["type"], "keyboard")

    def test_get_mouse_device_info(self):
        mock_mouse = MagicMock()
        mock_mouse.name = "Razer Naga Trinity"
        mock_mouse.type = "mouse"
        mock_mouse.serial = "PM1849H"
        mock_mouse.firmware_version = "v1.2"
        mock_mouse.has = MagicMock(return_value=False)
        mock_mouse.brightness = 100
        mock_mouse.dpi = (1800, 1800)
        mock_mouse.max_dpi = 16000
        mock_mouse.poll_rate = 500
        mock_mouse.capabilities = {"dpi": True, "poll_rate": True, "brightness": True}
        mock_mouse.fx = MagicMock()
        mock_mouse.fx.advanced = False

        res = get_device_info(mock_mouse)
        self.assertEqual(res["name"], "Razer Naga Trinity")
        self.assertEqual(res["type"], "mouse")
        self.assertEqual(res["poll_rate"], 500)
        self.assertEqual(res["supported_poll_rates"], [125, 500, 1000])
        self.assertEqual(res["dpi"], [1800, 1800])
        self.assertEqual(res["max_dpi"], 16000)

if __name__ == "__main__":
    unittest.main()
