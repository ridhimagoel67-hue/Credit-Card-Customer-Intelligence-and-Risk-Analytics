import pandas as pd

df = pd.read_csv(
    r'C:\Users\ridhi\OneDrive\Desktop\Credit_card_customer_analysis\data\raw\transactions_data.csv'
)

sample_df = df.sample(
    n=200000,
    random_state=42
)

sample_df.to_csv(
    'transactions_sample.csv',
    index=False
)