# Reflection

---

## Q1. When would you not use an AI agent for a data task?

When the task requires precise, deterministic logic where being subtly wrong
has downstream consequences that are hard to catch.

**1. Growth accounting classification logic.**
The users classification (New, Retained, Resurrected, Churned) depends on the 
date grain/period, so the logic is different for daily, weekly, and monthly periods. 
AI can also may create misclassifies logic, for the example Resurrected users as 
Retained (vice versa), or gets the period wrong. This kind of logic needs human 
who understands the exact business definition to write, review, and test the logic.

**2. Cohort retention consecutive logic.**
From my experience, consecutive cohort retention reflects real loyalty better than 
fixed cohort retention, and it also makes the line between Resurrected and Retained 
clearer. This kind of cohort retention might reflect the real retention and identify
how loyal the customer to us. If AI misinterpret on this part, it might produce numbers 
that looks good but it will give wrong intertpretation to the business owner or stakeholders.

**3. Dimension and fact table design.** 
Human inlolvement as the one who understand the business logic need to be hands-on on this
part. Decide what goes into dim_user and fct_events, also what approach to use, which columns 
to use requires understanding how downstream consumers will use the data based on the
requirements. AI may still can produce this as long as we write the right and specific prompt,
but it can't make these structural decisions correctly without the full business context.

---

## Q2. How do you evaluate the quality of LLM-generated outputs in a data context?

I read every sentence, review it by the technical knowledge and business knwoledge I know, then
I asked myself whether I actually agree with it or not.
For a column description specifically, I'd trust it if it's specific, and aligns with 
what I already know about the column and the business context. 

From my understanding, a good eval is one that reflects real human judgment. For the example, if
the result of LLM-generated outputs already align with the context and accurate, it doing well, 
and vice-versa. By human judgement we also can see how many people/team/project use the LLM, it
can be also prove of the usefullness for humans. 

---

## Q3. If the documentation agent shipped and started producing subtly wrong descriptions at scale, how would you catch it before it caused harm downstream?

At my previous role, an analyst made a bad analysis that build based on misunderstood requirements.
On the description case, it might be create a bad analysis and bad decision because the it build on
misunderstood description. 

For this case, the earliest signal is when the generated description doesn't align with the actual 
behavior of the column. For the example, if a column that stores a consecutive retention count gets 
described as a single period number, it will create incorrect output.

In my previous experience, the first thing on facing this issue I will stop/pause the job, alert the 
downstream users, fix the issue, then asses the impact as part of evaluation by doing manual checking.

---

## Q4. What is one AI-native capability you wish existed in the modern data stack today?

A data assistant that can answer business and anomaly questions, not detect it but also understand the 
data model, read the documentation, query the datamart, and explain the result in plain language to the 
stakeholders.

I believe there's already AI which detect the anomaly of something. In the data area, now AI can detect 
the anomaly happened on the result, but *as far as I know* it still can not detect on why behind it. On
my previous role, answering why a metric moved still required me to manually check across the data, 
pipelines and global situation, then do the deep dive.

For the example, when the retention dropped, while the conversion increased. We need to answer why this
happened, is it because of seassonal period, pipeline issue, or others.

The capability of that AI might be cover tracing the issue back trough the upstream if it's related to 
the pipeline, or check the global condition based on what happened on internet to suggest any possibility
that can affect the result, check another anomaly happened on the customer behaviour that may caused the
dropped. So human doesn't need extra time to check on many possibilities.