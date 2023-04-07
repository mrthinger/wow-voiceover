import re

def get_first_n_words(text, n):
    words = re.findall(r'\S+', text)
    first_n_words = words[:n]
    return ' '.join(first_n_words)