import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

file_path = os.path.join('Exports', 'Query 5 Controlling for the Storms.csv')

try:
    df = pd.read_csv(file_path)
    print("File loaded successfully!")
    print(df.head())
except FileNotFoundError:
    print(f"Error: The file was not found at {file_path}")


# Fix environment types for better label reading
df['env_short'] = df['environment_type'].apply(lambda x: x.split('. ')[1] if '. ' in x else x)

# Let's aggregate overall stats to see if the hypothesis holds
overall_stats = df.groupby('env_short').agg(
    total_incidents_sum=('total_incidents', 'sum'),
    avg_payout_mean=('avg_building_payout_2020_dollars', 'mean'),
    median_payout=('avg_building_payout_2020_dollars', 'median')
).reset_index()

print("Overall Stats:")
print(overall_stats.sort_values(by='total_incidents_sum', ascending=False))

# Identify top 5 storms by total incidents
top_storms_incidents = df.groupby('floodEventName')['total_incidents'].sum().nlargest(5).index
print("\nTop 5 Storms by Incidents:", top_storms_incidents.tolist())

# Filter data for top storms
df_top = df[df['floodEventName'].isin(top_storms_incidents)]


# Fix environment types for better label reading: remove the number prefix and insert a newline before the parentheses
def format_label(x):
    if '. ' in x:
        x = x.split('. ')[1]
    return x.replace(' (', '\n(')

df['env_label'] = df['environment_type'].apply(format_label)

# Aggregate overall stats
overall_stats = df.groupby('env_label').agg(
    total_incidents_sum=('total_incidents', 'sum'),
    avg_payout_mean=('avg_building_payout_2020_dollars', 'mean')
).reset_index()

# Sort both charts by total incidents (descending) to establish a consistent narrative order
sorted_stats = overall_stats.sort_values(by='total_incidents_sum', ascending=False)
common_order = sorted_stats['env_label'].tolist()

sns.set_theme(style="whitegrid")

# Figure 1: Total Incidents by Environment Type 
plt.figure(figsize=(12, 7))
ax1 = sns.barplot(data=overall_stats, x='env_label', y='total_incidents_sum', order=common_order, palette='Blues_d')

# Add title inside the chart
ax1.text(0.5, 0.95, 'Total Flooding Incidents by Environment Type', 
         transform=ax1.transAxes, ha='center', va='top', 
         fontsize=16, weight='bold', 
         bbox=dict(facecolor='white', alpha=0.9, edgecolor='none', boxstyle='round,pad=0.5'))

plt.ylabel('Total Incident Count', fontsize=14)
plt.xlabel('Environment Type', fontsize=12)
plt.xticks(fontsize=14) 

ymin, ymax = ax1.get_ylim()
ax1.set_ylim(ymin, ymax * 1.1)

plt.tight_layout()
plt.savefig('total_incidents_env.png', dpi = 600)
plt.close()

# Figure 2: Avg Payout by Environment Type
plt.figure(figsize=(12, 7))
ax2 = sns.barplot(data=overall_stats, x='env_label', y='avg_payout_mean', order=common_order, palette='Reds_d')

# Add title inside the chart
ax2.text(0.5, 0.95, 'Average Payout (2020 USD) by Environment Type', 
         transform=ax2.transAxes, ha='center', va='top', 
         fontsize=16, weight='bold', 
         bbox=dict(facecolor='white', alpha=0.9, edgecolor='none', boxstyle='round,pad=0.5'))

plt.ylabel('Avg Building Payout ($)', fontsize=14)
plt.xlabel('Environment Type', fontsize=12)
plt.xticks(fontsize=14)

# Adjust y-limit here too
ymin, ymax = ax2.get_ylim()
ax2.set_ylim(ymin, ymax * 1.1)

plt.tight_layout()
plt.savefig('avg_payout_env.png', dpi = 600)
plt.close()

# Figure 3: Grouped Bar Chart for Top 5 Storms - Avg Payout
plt.figure(figsize=(14, 8))
sns.barplot(data=df_top, x='floodEventName', y='avg_building_payout_2020_dollars', hue='env_short')
plt.title('Average Payouts Across Top 5 Major Storms by Environment Type', fontsize=16)
plt.ylabel('Average Payout (2020 USD)')
plt.xlabel('Major Storm Event')
plt.legend(title='Environment Type', bbox_to_anchor=(1.05, 1), loc='upper left')
plt.tight_layout()
plt.savefig('grouped_payout_top_storms.png', dpi = 600)
plt.close()

# Figure 4: Grouped Bar Chart for Top 5 Storms - Incidents
plt.figure(figsize=(14, 8))
sns.barplot(data=df_top, x='floodEventName', y='total_incidents', hue='env_short')
plt.title('Total Incidents Across Top 5 Major Storms by Environment Type', fontsize=16)
plt.ylabel('Total Incidents')
plt.xlabel('Major Storm Event')
plt.legend(title='Environment Type', bbox_to_anchor=(1.05, 1), loc='upper left')
plt.tight_layout()
plt.savefig('grouped_incidents_top_storms.png', dpi = 600)
plt.close()