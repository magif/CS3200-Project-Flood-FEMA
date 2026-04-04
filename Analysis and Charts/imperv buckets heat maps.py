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

# Ensure Year is treated as integer for cleaner columns
df['Year'] = df['Year'].astype(int)

# 1. Heat Map for Volume (Total Claims)
# Pivot the data: Rows = Impervious %, Columns = Year, Values = Total Claims
pivot_claims = df.pivot(index="Percent Impervious Surface", columns="Year", values="Total Claims")

# Reverse the index so 100% is at the top of the y-axis
pivot_claims = pivot_claims.sort_index(ascending=False)

plt.figure(figsize=(15, 7))
sns.heatmap(pivot_claims, cmap="Blues", annot=False, linewidths=.5)
plt.title("Heat Map 1: Total Claim Volume (The 'Volume Illusion')\nDarker blue = higher number of claims")
plt.ylabel("Percent Impervious Surface (%)")
plt.xlabel("Year of Loss")
plt.tight_layout()
plt.savefig('heatmap_volume.png', dpi = 600)
plt.close()


# 2. Heat Map for Severity (Average Payout)
# Pivot the data: Rows = Impervious %, Columns = Year, Values = Avg Payout
pivot_payout = df.pivot(index="Percent Impervious Surface", columns="Year", values="Avg Payout per Claim (2020 Dollars)")

# Reverse the index so 100% is at the top
pivot_payout = pivot_payout.sort_index(ascending=False)

plt.figure(figsize=(15, 7))
sns.heatmap(pivot_payout, cmap="Reds", annot=False, linewidths=.5)
plt.title("Heat Map 2: Average Claim Severity (The 'Financial Reality')\nDarker red = higher average payout (2020$)")
plt.ylabel("Percent Impervious Surface (%)")
plt.xlabel("Year of Loss")
plt.tight_layout()
plt.savefig('heatmap_severity.png', dpi = 600)
plt.close()



print("Heatmaps generated.")

plt.show()