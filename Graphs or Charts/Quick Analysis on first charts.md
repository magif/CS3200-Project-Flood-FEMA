**"Claims per 100 Policies"**. It normalizes the data. It tells us how the environment (concrete vs. nature) actually impacts the frequency of claims, completely independent of population density.

### **1\. A Trap: Total Payouts by Impervious Surface**

payouts\_by\_surface.png  
This first bar chart to show what *not* to rely on exclusively, though it's still useful for say accountants. This bar chart aggregates the total historical financial damage based on the percentage of impervious surface (concrete, asphalt, buildings). It tells you where the money went, but again, it’s heavily skewed by where infrastructure is heavily developed.

### **2\. The Core Insight: Impervious Surface vs. Claim Frequency**

This scatter plot is where the real story lives. I mapped the **Percent Impervious Surface** directly against **Claims per 100 Policies**, adding a regression line.

* **Why it matters:** Every single dot is an intersection of time and surface level. If you see an upward trend in the red regression line, it would prove that paving over the environment directly spikes the likelihood of a claim being filed.  
  * But it doesn't\!  
*  *Does more concrete equal more guaranteed flooding per policyholder?*  
  * Actually a slight de-correlation closer to normal randomness.

### **3\. The Big Picture: Claim Frequency Trends Over Time**

For this one, I binned Impervious Surface data into three tiers: Low (0-33%), Medium (34-66%), and High (67-100% concrete). Then I tracked the average claim frequency from 1985 to 2023\.

* **Why it matters:** Climate change and urban sprawl aren't static. This chart immediately reveals if the gap between "high concrete" and "low concrete" areas is widening as the years go on. If the "High" line is tearing away from the pack in recent years, it means the compounding effect of severe weather and zero drainage is getting exponentially worse over time.  
* But instead it appears claim frequency is actually increasing for lesser developed areas. Is this saying that more paved areas arent flooding as much or is the more developed area also getting the drainage infrastructure as a result of development.  
* Furthermore if low impervious surface areas are having higher claims, is this a sign of climate change? Or are more people moving out of cities and buying policies in out in the more rural outskirts of a town and said areas although more permeable also lack drainage infrastructure when floods and major storm events happen.

If you just look at the raw dollars, you're missing the actual mechanics of the risk. Always normalize the data. What do you think—does looking at the normalized "Claims per 100 Policies" change your initial read on what this dataset was trying to say?

---

If we simply plot "Total Payouts," the heatmap will just light up wherever the most people live. It becomes a population map, not a risk map. In finding the "bad years" versus the "consistently expensive areas"

Calculated a new column: **Payout per 100 Policies**. We get this by multiplying the claim frequency (*Claims per 100 Policies*) by the *Average Payout*. This gives us the true, localized financial "burn rate" of a neighborhood, regardless of whether 10 people or 10,000 people live there.

I've generated two heatmaps based on this logic:

### **1\. Normalized Financial Risk (Payouts per 100 Policies)**

This is the holy grail for your question. Here’s how you read it:

* **Vertical columns of dark red:** These are your "bad years." If you look at specific years (like 2005, 2012, 2017 notorious for hurricanes like Katrina, Sandy, Harvey), you'll see a vertical stripe where *everyone* got hit, regardless of how much concrete was on the ground.  
* **Horizontal bands of dark red:** These are your "consistently expensive areas." Look at the top half of the Y-axis (the 60-100% impervious surface range). Although not definitive, when a year is hit bad (vertically) the payout intensity (darker red) get higher with high impervious surface %   
  But counterintuitively, lower impervious % have more consistent payout intensity albeit max intensity is mild vs higher impervious %.  
* This shows a slight correlation that high-concrete environments don't just get unlucky during massive storms; they tend to bleed money harder when even small storms hit  
* however  consistently, year after year, even in "quiet" years. Lower impervious zones are still bleeding more than before. (climate change, river, levy overflows?)

### **2\. Claim Severity (Average Payout per Claim)**

I ran this second heatmap using just the **Average Payout** because I wanted to see if the *damage per house* scales with concrete, not just the frequency.

* Does a flooded basement in a highly paved area cost more to fix than one in a natural area?  
* If the top rows (100% paved) are darker than the bottom rows (0% paved) across the board, it means concrete doesn't just cause *more* floods, it causes *deeper, more destructive* floods because the water pools instantly and breaches higher into the structures.  
  * Although not conclusive, higher impervious zones do average larger payouts (more damage)