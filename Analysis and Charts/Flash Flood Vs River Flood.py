import pandas as pd
import matplotlib.pyplot as plt
import os

file_path = os.path.join('Exports', 'Flash Flooding vs. River Flooding.csv')

try:
    df = pd.read_csv(file_path)
    print("File loaded successfully!")
    print(df.head())
except FileNotFoundError:
    print(f"Error: The file was not found at {file_path}")

# Enforce the order of environments
env_order = ['High Concrete', 'High Natural']
df['environment_type'] = pd.Categorical(df['environment_type'], categories=env_order, ordered=True)

# Create pivot tables for percentages (for bar height) and incidents (for labels)
perc_pivot = df.pivot_table(index='environment_type', columns='flood_type', values='percent_of_environment').loc[env_order]
inc_pivot = df.pivot_table(index='environment_type', columns='flood_type', values='total_incidents').loc[env_order]

# Set up the visualization
fig, ax = plt.subplots(figsize=(10, 6))
colors = ['#3498db', '#e74c3c'] 

# Create the 100% stacked bar chart
perc_pivot.plot(kind='bar', stacked=True, color=colors, ax=ax, edgecolor='white', width=0.6)

# Iterate through the containers (each represents one stack/flood_type across all environments)
for c_idx, container in enumerate(ax.containers):
    flood_type = perc_pivot.columns[c_idx]
    
    for b_idx, bar in enumerate(container):
        height = bar.get_height()
        if height > 0:
            env_type = perc_pivot.index[b_idx]
            incident_count = inc_pivot.loc[env_type, flood_type]
            
            # Format the label with commas for readability
            label = f"{int(incident_count):,} claims\n({height:.1f}%)"
            
            # Place the label in the vertical center of each bar segment
            ax.annotate(label,
                        (bar.get_x() + bar.get_width() / 2, bar.get_y() + height / 2),
                        ha='center', va='center',
                        fontsize=11, color='white', fontweight='bold')

# Customize titles and axes
plt.title('Proportion of Flood Claims by Environment', fontsize=14, fontweight='bold')
plt.xlabel('Environment Type', fontsize=12)
plt.ylabel('Percentage of Environment\'s Total Claims (%)', fontsize=12)
plt.xticks(rotation=0)
plt.ylim(0, 100)
plt.legend(title='Flood Type', bbox_to_anchor=(1.05, 1), loc='upper left')
plt.tight_layout()

plt.savefig('flood_stacked_analysis.png')
print("Plot saved as flood_stacked_analysis.png")

plt.show()