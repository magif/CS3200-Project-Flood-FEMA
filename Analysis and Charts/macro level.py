import pandas as pd
import matplotlib.pyplot as plt
import os

file_path = os.path.join('Exports', 'macro-level temporal trends floods.csv')

try:
    df = pd.read_csv(file_path)
    print("File loaded successfully!")
    print(df.head())
except FileNotFoundError:
    print(f"Error: The file was not found at {file_path}")

# --- Plot 1: Total Claims & Real Cost Over Time ---
fig, ax1 = plt.subplots(figsize=(12, 6))

color1 = '#3498db'
ax1.set_xlabel('Year of Loss', fontweight='bold')
ax1.set_ylabel('Total Claims Count', color=color1, fontweight='bold')
# Make bars sorted by year (already sorted in dataset, but ensuring sequence)
ax1.bar(df['yearOfLoss'], df['total_claims'], color=color1, alpha=0.7, label='Total Claims')
ax1.tick_params(axis='y', labelcolor=color1)
ax1.grid(axis='y', linestyle='--', alpha=0.3)

ax2 = ax1.twinx()  
color2 = '#e74c3c'
ax2.set_ylabel('Real Total Paid Out (2020 USD)', color=color2, fontweight='bold')  
ax2.plot(df['yearOfLoss'], df['real_total_paid_out_2020'], color=color2, marker='o', linewidth=2.5, label='Real Paid Out (2020$)')
ax2.tick_params(axis='y', labelcolor=color2)

plt.title('Macro-Level Trend: Flood Insurance Claims & Real Payouts (1985-Present)', fontweight='bold')
fig.tight_layout()  
plt.savefig('claims_and_payouts_trend.png', dpi = 600)
plt.close()

# --- Plot 2: Flood Characteristics Trends ---
fig, ax = plt.subplots(figsize=(12, 6))
ax.plot(df['yearOfLoss'], df['pct_severe_above_ground_floods'] * 100, label='Severe Above Ground (>12")', color='#8e44ad', marker='s', linewidth=2)
ax.plot(df['yearOfLoss'], df['pct_basement_floods'] * 100, label='Basement Floods', color='#2c3e50', marker='^', linewidth=2)
ax.plot(df['yearOfLoss'], df['pct_primary_residence'] * 100, label='Primary Residence', color='#27ae60', marker='d', linewidth=2)

ax.set_title('Shifting Nature of Floods: Severity & Location Type', fontweight='bold')
ax.set_xlabel('Year of Loss', fontweight='bold')
ax.set_ylabel('Percentage (%) of Total Claims', fontweight='bold')
ax.legend(loc='upper left')
ax.grid(True, linestyle='--', alpha=0.5)

fig.tight_layout()
plt.savefig('flood_characteristics_trend.png', dpi = 600)
plt.close()