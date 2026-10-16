import urllib.request
import os

assets = [
    {
        "id": "d29f200d474f430c8b56a38217fa8a23",
        "title": "Chaperoned Match Chat",
        "img_filename": "stitch/images/1_chaperoned_match_chat.png",
        "img_url": "https://lh3.googleusercontent.com/aida/AEtjO1Vb28Yqq0DX34Crt6kKi_L2qXeppUXgFyJoUtO0swjcuUsC9Jyw3PNL1mBREtbGb1Q4Ep8iqV5VopN8zX6za0v4kNdcp-FFMpWoeeMWsuJ9p2uxskf1E9Fmz_X1ww9o34GkqwAQt5R_aLsVVTkqgfx1quaTz943NDG_k4DAbZ-MtMWjPjFddRVis5BXdt7Bu3ufEETuSD6slak030VlfzTS_DF44_nv-c-kE_AvUmVWOvViFOFxDF1-TVpW",
        "html_filename": "stitch/html/1_chaperoned_match_chat.html",
        "html_url": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZGJkYzhjZmU1ZjUwNzc5OWVkNzMzMWMyYzNlEgsSBxD9u8LziAQYAZIBJAoKcHJvamVjdF9pZBIWQhQxMjk5MzAyNTU3NDQ1Mzc3MTE5NQ&filename=&opi=89354086"
    },
    {
        "id": "6ffa154358c24569bb090e761ba89c2a",
        "title": "Wali & Privacy Hub",
        "img_filename": "stitch/images/2_wali_privacy_hub.png",
        "img_url": "https://lh3.googleusercontent.com/aida/AEtjO1UfwkqtDnOXc7KtZ1muX-N3ru3Zi0eL150f15jsMyvBifG8nVHj4qt0oTAPd9SBmNxua02Afjy08RMKqTdpGeG1DymKgw-J9rXOD0_bvYMpp1nvynqbnG7UN-LmQdQmtFwuCX_kgu_-xfDkeWAHWSu5RgNIi5W6v9i-P3bvtdUHx_t3DUaN_mrYBHI_ZZQRLVGbhOV2-wa5GH80A2FcnySxR_Qgn_Gdek-kunMRtS-JQJr2GxAN5BG_3efW",
        "html_filename": "stitch/html/2_wali_privacy_hub.html",
        "html_url": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZGJkYzk5NTQwZTkwMjA3YTU2NmM0MGVhNzY3EgsSBxD9u8LziAQYAZIBJAoKcHJvamVjdF9pZBIWQhQxMjk5MzAyNTU3NDQ1Mzc3MTE5NQ&filename=&opi=89354086"
    },
    {
        "id": "be0fbfc427914dc5a26295410cd1b10f",
        "title": "Detailed Profile View",
        "img_filename": "stitch/images/3_detailed_profile_view.png",
        "img_url": "https://lh3.googleusercontent.com/aida/AEtjO1WgaQ_2nOQiACmiS35TgFfE9x1eCmlZe2Rr2v1X--tFeCzJIzwWLQR2TRIsjdKE3rJLtNeUJCXVNrBugjP99LiI1RwL2KeF6q1qXx6vdi0M8uRFCVnNJx61lpnpmhyUpBq9TZh-BqeTruiFZlWC7h8dvOmZEKD0Tsztyck8HIf3hRfwvx05MGRpqbTbNyWlM4KhRTmmJX6pk1R4Ka7l1AA69qoflU4AstpC6ST8EZwaGJwfB49NLq3SYLg",
        "html_filename": "stitch/html/3_detailed_profile_view.html",
        "html_url": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZGJkY2E0NWU1MDkwNTIyODEzOTBjMDgyYTMyEgsSBxD9u8LziAQYAZIBJAoKcHJvamVjdF9pZBIWQhQxMjk5MzAyNTU3NDQ1Mzc3MTE5NQ&filename=&opi=89354086"
    },
    {
        "id": "b3c1699b4796437780948aab30ccf7ca",
        "title": "Discovery & Matches",
        "img_filename": "stitch/images/4_discovery_matches.png",
        "img_url": "https://lh3.googleusercontent.com/aida/AEtjO1W3wbfLEhxYYVs_RjzW1HqOQoWmYZub8QXuLTI0gxlNn6J0ssrlAWtaSih9UR4Ictnde1DSg0Mv6K5CzYf8dpL8keFDkyYvW7cG_YZebKyiLlPHLaV4B6nDBVeplEzdoGhz8BrX2PeIARyV_tnv-_PhZ81AYUdGhLsHCmaYyZDMJpQ3-QAEhT39wwMS62_S0W_Y7WwFbFfGfw-rVt7mwqAtWDPHUS4lDnbcpxYEEomWhPP2ZjNDlkfvQbb3",
        "html_filename": "stitch/html/4_discovery_matches.html",
        "html_url": "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzAwMDY1ZGJkYzhlMjdlNzYwOTEwN2Y3Y2RlMzQ1MWJmEgsSBxD9u8LziAQYAZIBJAoKcHJvamVjdF9pZBIWQhQxMjk5MzAyNTU3NDQ1Mzc3MTE5NQ&filename=&opi=89354086"
    }
]

headers = {'User-Agent': 'Mozilla/5.0'}

for item in assets:
    print(f"Downloading {item['title']} image...")
    req = urllib.request.Request(item['img_url'], headers=headers)
    with urllib.request.urlopen(req) as resp, open(item['img_filename'], 'wb') as f:
        f.write(resp.read())

    print(f"Downloading {item['title']} HTML...")
    req = urllib.request.Request(item['html_url'], headers=headers)
    with urllib.request.urlopen(req) as resp, open(item['html_filename'], 'wb') as f:
        f.write(resp.read())

print("All Stitch assets successfully downloaded!")
