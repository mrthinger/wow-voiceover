import re

def get_first_n_words(text, n):
    words = re.findall(r'\S+', text)
    first_n_words = words[:n]
    return ' '.join(first_n_words)

def get_last_n_words(text, n):
    words = re.findall(r'\S+', text)
    last_n_words = words[-n:]
    return ' '.join(last_n_words)
    
def replace_dollar_bs_with_space(text):
    pattern = r'(\$[Bb])+'
    result = re.sub(pattern, ' ', text)
    return result

def language_code_to_language_number(local_code: str) -> int:
    match local_code:
        case "enUS" | "enGB":
            return 0
        case "koKR":
            return 1
        case "frFR":
            return 2
        case "deDE":
            return 3
        case "zhCN":    # Simplified chinese
            return 4
        case "zhTW":    # Traditional chinese
            return 5
        case "esES":    # European spanish
            return 6
        case "esMX":    # Mexican spanish
            return 7
        case "ruRU":
            return 8
        case _:
            raise Exception("Unsupported local code!")
