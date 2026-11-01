#!/bin/bash
set -e

mkdir -p stitch/images stitch/html

echo "Downloading Screen 1: Chaperoned Match Chat..."
curl -L -s -o "stitch/images/1_chaperoned_match_chat.png" "https://lh3.googleusercontent.com/aida/AEtjO1Vb28Yqq0DX34Crt6kKi_L2qXeppUXgFyJoUtO0swjcuUsC9Jyw3PNL1mBREtbGb1Q4Ep8iqV5VopN8zX6za0v4kNdcp-FFMpWoeeMWsuJ9p2uxskf1E9Fmz_X1ww9o34GkqwAQt5R_aLsVVTkqgfx1quaTz943NDG_k4DAbZ-MtMWjPjFddRVis5BXdt7Bu3ufEETuSD6slak030VlfzTS_DF44_nv-c-kE_AvUmVWOvViFOFxDF1-TVpW"
curl -L -s -o "stitch/html/1_chaperoned_match_chat.html" "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZGJkYzhjZmU1ZjUwNzc5OWVkNzMzMWMyYzNlEgsSBxD9u8LziAQYAZIBJAoKcHJvamVjdF9pZBIWQhQxMjk5MzAyNTU3NDQ1Mzc3MTE5NQ&filename=&opi=89354086"

echo "Downloading Screen 2: Wali & Privacy Hub..."
curl -L -s -o "stitch/images/2_wali_privacy_hub.png" "https://lh3.googleusercontent.com/aida/AEtjO1UfwkqtDnOXc7KtZ1muX-N3ru3Zi0eL150f15jsMyvBifG8nVHj4qt0oTAPd9SBmNxua02Afjy08RMKqTdpGeG1DymKgw-J9rXOD0_bvYMpp1nvynqbnG7UN-LmQdQmtFwuCX_kgu_-xfDkeWAHWSu5RgNIi5W6v9i-P3bvtdUHx_t3DUaN_mrYBHI_ZZQRLVGbhOV2-wa5GH80A2FcnySxR_Qgn_Gdek-kunMRtS-JQJr2GxAN5BG_3efW"
curl -L -s -o "stitch/html/2_wali_privacy_hub.html" "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZGJkYzk5NTQwZTkwMjA3YTU2NmM0MGVhNzY3EgsSBxD9u8LziAQYAZIBJAoKcHJvamVjdF9pZBIWQhQxMjk5MzAyNTU3NDQ1Mzc3MTE5NQ&filename=&opi=89354086"

echo "Downloading Screen 3: Detailed Profile View..."
curl -L -s -o "stitch/images/3_detailed_profile_view.png" "https://lh3.googleusercontent.com/aida/AEtjO1WgaQ_2nOQiACmiS35TgFfE9x1eCmlZe2Rr2v1X--tFeCzJIzwWLQR2TRIsjdKE3rJLtNeUJCXVNrBugjP99LiI1RwL2KeF6q1qXx6vdi0M8uRFCVnNJx61lpnpmhyUpBq9TZh-BqeTruiFZlWC7h8dvOmZEKD0Tsztyck8HIf3hRfwvx05MGRpqbTbNyWlM4KhRTmmJX6pk1R4Ka7l1AA69qoflU4AstpC6ST8EZwaGJwfB49NLq3SYLg"
curl -L -s -o "stitch/html/3_detailed_profile_view.html" "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZGJkY2E0NWU1MDkwNTIyODEzOTBjMDgyYTMyEgsSBxD9u8LziAQYAZIBJAoKcHJvamVjdF9pZBIWQhQxMjk5MzAyNTU3NDQ1Mzc3MTE5NQ&filename=&opi=89354086"

echo "Downloading Screen 4: Discovery & Matches..."
curl -L -s -o "stitch/images/4_discovery_matches.png" "https://lh3.googleusercontent.com/aida/AEtjO1W3wbfLEhxYYVs_RjzW1HqOQoWmYZub8QXuLTI0gxlNn6J0ssrlAWtaSih9UR4Ictnde1DSg0Mv6K5CzYf8dpL8keFDkyYvW7cG_YZebKyiLlPHLaV4B6nDBVeplEzdoGhz8BrX2PeIARyV_tnv-_PhZ81AYUdGhLsHCmaYyZDMJpQ3-QAEhT39wwMS62_S0W_Y7WwFbFfGfw-rVt7mwqAtWDPHUS4lDnbcpxYEEomWhPP2ZjNDlkfvQbb3"
curl -L -s -o "stitch/html/4_discovery_matches.html" "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZGJkYzhlMjdlNzYwOTEwN2Y3Y2RlMzQ1MWJmEgsSBxD9u8LziAQYAZIBJAoKcHJvamVjdF9pZBIWQhQxMjk5MzAyNTU3NDQ1Mzc3MTE5NQ&filename=&opi=89354086"

echo "Done downloading all Stitch assets!"
