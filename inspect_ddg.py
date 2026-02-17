import requests
from bs4 import BeautifulSoup

def inspect_ddg(term):
    url = "https://html.duckduckgo.com/html/"
    params = {"q": term, "b": ""}
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    # 1. Fetch First Page
    print(f"Fetching '{term}'...")
    response = requests.get(url, params=params, headers=headers)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Inspect Image Results
    print("\n--- Image Results Structure ---")
    # Usually <div class="tile ...">...<img class="tile--img__img" src="...">...</div>
    images = soup.find_all("img", class_="tile--img__img")
    print(f"Found {len(images)} images with class 'tile--img__img'.")
    if images:
        print(f"Sample 1 src: {images[0].get('src')}")
        print(f"Sample 1 parent class: {images[0].parent.get('class')}")

    # Inspect Pagination
    print("\n--- Pagination Structure ---")
    # Usually a form with input type="submit" value="Next" or similar
    forms = soup.find_all("form")
    for i, f in enumerate(forms):
        inputs = f.find_all("input")
        input_info = [f"name={inp.get('name')} value={inp.get('value')}" for inp in inputs]
        print(f"Form {i}: action={f.get('action')} inputs={input_info}")

if __name__ == "__main__":
    inspect_ddg("akita dog")
