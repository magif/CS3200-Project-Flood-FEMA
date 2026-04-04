import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

file_path = os.path.join('Exports', 'development % buckets payout by year.csv')

try:
    df = pd.read_csv(file_path)
    print("File loaded successfully!")
    print(df.head())
except FileNotFoundError:
    print(f"Error: The file was not found at {file_path}")


# Display basic info
print(df.info())
print(df.head())

# Setup for plots
sns.set_theme(style="whitegrid")

# 1. Total Claims vs. Percent Impervious Surface (Aggregated across all years)
agg_claims = df.groupby('Percent Impervious Surface')['Total Claims'].sum().reset_index()
plt.figure(figsize=(10, 6))
sns.barplot(data=agg_claims, x='Percent Impervious Surface', y='Total Claims', palette="viridis")
plt.title('Total Flood Claims by Impervious Surface Percentage (1985-2023)')
plt.xlabel('Percent Impervious Surface (%)')
plt.ylabel('Total Number of Claims')
plt.tight_layout()
plt.savefig('total_claims_by_impervious.png', dpi = 600)
plt.close()

# 2. Avg Payout per Claim vs. Percent Impervious Surface
# We need to calculate a weighted average for the payout per claim across all years
weighted_avg = df.groupby('Percent Impervious Surface').apply(
    lambda x: x['Total Payouts (2020 Dollars)'].sum() / x['Total Claims'].sum() if x['Total Claims'].sum() > 0 else 0
).reset_index(name='Weighted Avg Payout (2020$)')

plt.figure(figsize=(10, 6))
sns.barplot(data=weighted_avg, x='Percent Impervious Surface', y='Weighted Avg Payout (2020$)', palette="magma")
plt.title('Average Payout per Claim by Impervious Surface Percentage')
plt.xlabel('Percent Impervious Surface (%)')
plt.ylabel('Average Payout (2020 USD)')
plt.tight_layout()
plt.savefig('avg_payout_by_impervious.png', dpi = 600)
plt.close()

# 3. Time Series of Total Claims for different Impervious Buckets (Simplified to broad groups to avoid clutter)
# Group into low (0-30), med (40-60), high (70-100)
def categorize_impervious(x):
    if x <= 30: return 'Low (0-30%)'
    elif x <= 60: return 'Medium (40-60%)'
    else: return 'High (70-100%)'

df['Impervious Category'] = df['Percent Impervious Surface'].apply(categorize_impervious)
yearly_trend = df.groupby(['Year', 'Impervious Category'])['Total Claims'].sum().reset_index()

plt.figure(figsize=(12, 6))
sns.lineplot(data=yearly_trend, x='Year', y='Total Claims', hue='Impervious Category', marker="o")
plt.title('Trend of Total Flood Claims Over Time by Impervious Density')
plt.xlabel('Year')
plt.ylabel('Total Claims')
plt.tight_layout()
plt.savefig('claims_trend_over_time.png', dpi = 600)
plt.close()



print("Data processing and plot generation complete.")

plt.show()