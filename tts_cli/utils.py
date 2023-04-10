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