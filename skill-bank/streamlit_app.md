# Skill Template: Streamlit App

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific app structure, data sources, and deployment setup.

## When to Use

Use this skill for tasks that involve creating interactive dashboards and visualisation apps with Streamlit.

## File Location

Each app gets its own directory:

```
{project}/visualizations/{app_name}/
├── __init__.py
├── app.py              # Entry point
├── components.py       # Reusable UI components (if needed)
├── queries.py          # Data loading functions
└── Dockerfile          # Container definition
```

## App Structure

### app.py (entry point)

```python
import streamlit as st
from myapp.queries import load_data

st.set_page_config(page_title="App Title", layout="wide")
st.title("App Title")

# Sidebar for filters
with st.sidebar:
    date_range = st.date_input("Date range", value=[start, end])
    category = st.selectbox("Category", options=categories)

# Main content
data = load_data(date_range, category)

col1, col2 = st.columns(2)
with col1:
    st.metric("Total Count", f"{data['count'].sum():,}")
with col2:
    st.metric("Total Value", f"${data['value'].sum():,.0f}")

st.dataframe(data)
```

### queries.py (data loading)

```python
import streamlit as st
import pandas as pd


@st.cache_data(ttl=3600)
def load_data(date_range, category) -> pd.DataFrame:
    """Load data from the warehouse."""
    client = create_client()
    query = """
        SELECT id, category, count, value
        FROM analytics_table
        WHERE event_date BETWEEN @start_date AND @end_date
        AND category = @category
    """
    # Use parameterised queries — never f-strings for SQL
    ...
    return df
```

## Conventions

- Use `@st.cache_data` for all data reads with an appropriate TTL
- Parameterise all queries — never use f-strings for SQL
- Sidebar for filters, main area for charts and tables
- Use `st.columns()` for side-by-side metrics
- Use `st.tabs()` for multi-section views
- Default port: 8501
- No authentication in app code — handled by infrastructure

## Layout Patterns

### Metric cards
```python
cols = st.columns(4)
for col, (label, value) in zip(cols, metrics.items()):
    col.metric(label, value)
```

### Charts
```python
import plotly.express as px

fig = px.line(data, x="date", y="value", color="category")
st.plotly_chart(fig, use_container_width=True)
```

Use plotly for charts, preferring plotly.express where possible.

## Mock Data Convention

When a page is created during prototyping/design, it may use mock data with a conditional import pattern. Build agents must replace these with real data imports once the real data module is built and tested.

### Identifying mock imports

Look for this pattern in page files:

```python
try:
    from myapp.data.real_module import fetch_data
    df = fetch_data(start_date, end_date)
except (ImportError, RuntimeError):
    from myapp.data.mock_data import get_mock_data
    df = get_mock_data()
```

### Replacing with real data

Once the real data module exists and is tested:

1. Replace the try/except block with a direct import
2. Check design specs for the mock-to-real mapping table
3. If `mock_data.py` has no remaining consumers, delete it
4. Verify the page renders with real data by running the app locally

## Running Locally

```bash
streamlit run {project}/visualizations/{app_name}/app.py
```

## Testing

- Test query functions with mocked database clients (`testing` skill)
- Test data transformation logic with synthetic DataFrames (`testing` skill)
- Test page rendering and widget interactions with Streamlit AppTest (`streamlit_testing` skill)

## File Checklist

When creating or modifying a Streamlit app, ensure:
1. `app.py` entry point exists
2. `queries.py` for data loading
3. `Dockerfile` for deployment
4. Tests for query functions and page rendering
