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

def language_code_to_language_number(local_code : str) -> int:
    match local_code:
        case "ko":
            return 1
        case "fr":
            return 2
        case "de":
            return 3
        case "zh":
            return 4            # Not sure what the difference between 4 and 5 is
        case "es":
            return 6            # Not sure why spain is 6 and 7
        case "ru":
            return 8
        case _:
            raise Exception("Unsupported local code!")