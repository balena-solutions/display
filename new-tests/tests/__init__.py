"""
Test registry.

TestResult is defined in tests.result to avoid circular imports.
It is re-exported here for convenience.

ALL_TESTS is the ordered list of all tests. To add a new test:
  1. Create a runner function in the appropriate module (or a new module).
  2. Append an entry to ALL_TESTS below.
"""

from tests.result import TestResult  # re-exported for convenience
from tests.gles import run_gles_texture, run_gles_shading, run_gles_jellyfish
from tests.vulkan import run_vulkan_vertex, run_vulkan_texture, run_vulkan_shading
from tests.video import run_video_h264_720p30, run_video_h264_1080p60, run_video_h265_1080p60


# Ordered list of all tests. Each entry maps an id to a runner function.
ALL_TESTS = [
    {
        "id":    "gles_texture",
        "name":  "GLES Texture Fill",
        "group": "OpenGL ES",
        "fn":    run_gles_texture,
    },
    {
        "id":    "gles_shading",
        "name":  "GLES Shading (Phong)",
        "group": "OpenGL ES",
        "fn":    run_gles_shading,
    },
    {
        "id":    "gles_jellyfish",
        "name":  "GLES Jellyfish",
        "group": "OpenGL ES",
        "fn":    run_gles_jellyfish,
    },
    {
        "id":    "vulkan_vertex",
        "name":  "Vulkan Vertex",
        "group": "Vulkan",
        "fn":    run_vulkan_vertex,
    },
    {
        "id":    "vulkan_texture",
        "name":  "Vulkan Texture",
        "group": "Vulkan",
        "fn":    run_vulkan_texture,
    },
    {
        "id":    "vulkan_shading",
        "name":  "Vulkan Shading",
        "group": "Vulkan",
        "fn":    run_vulkan_shading,
    },
    {
        "id":    "video_h264_720p30",
        "name":  "H.264 720p 30fps",
        "group": "Video",
        "fn":    run_video_h264_720p30,
    },
    {
        "id":    "video_h264_1080p60",
        "name":  "H.264 1080p 60fps",
        "group": "Video",
        "fn":    run_video_h264_1080p60,
    },
    {
        "id":    "video_h265_1080p60",
        "name":  "H.265 1080p 60fps",
        "group": "Video",
        "fn":    run_video_h265_1080p60,
    },
]
