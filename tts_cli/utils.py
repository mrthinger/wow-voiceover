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

def local_number_to_code(local_number: int) -> str:
    if local_number == 1:
        return "ko"
    elif local_number == 2:
        return "fr"
    elif local_number == 3:
        return "de"
    elif local_number == 4:
        return "zh"
    elif local_number == 5:
        return "zh"             # This one should be traditionale chinese
    elif local_number == 6:
        return "es"
    elif local_number == 7:
        return "es"             # Not sure whats the different between 6 and 7
    elif local_number == 8:
        return "ru"
    
    raise Exception("Unsupported local_number!")

def is_valid_local_number(local_number: int) -> bool:
    try:
        local_number_to_code(local_number)
        return True
    except Exception:
        return False