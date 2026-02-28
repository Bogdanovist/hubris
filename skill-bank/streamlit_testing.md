# Skill Template: Streamlit Testing

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific app paths, data dependencies, and test file locations.

## When to Use

Use this skill when testing Streamlit app pages, components, and user interactions. This complements unit tests (which test query functions and data logic with mocks) by validating that pages render correctly and widgets behave as expected.

This is NOT for testing data pipelines against real data (use the `data_e2e_testing` skill) or for unit testing pure functions (use the `testing` skill). These tests exercise the Streamlit rendering layer with mocked data dependencies.

## Framework

Streamlit's built-in headless testing framework:

```python
from streamlit.testing.v1 import AppTest
```

Tests run via pytest, not as standalone scripts.

## Creating an AppTest Instance

### From a file (for full pages)

```python
from streamlit.testing.v1 import AppTest

at = AppTest.from_file("path/to/pages/my_page.py", default_timeout=10)
at.run()
```

Use `from_file` when testing a complete page. The path is relative to the repo root.

### From a function (for isolated components)

```python
from streamlit.testing.v1 import AppTest

def render_controls():
    import streamlit as st
    from myapp.components.controls import render_filter_control
    render_filter_control()

at = AppTest.from_function(render_controls)
at.run()
```

Use `from_function` when testing a single component in isolation.

## Querying Elements

After `at.run()`, access rendered elements by type. Each type returns an indexed sequence:

```python
at.run()

# Text elements
at.title[0].value          # first st.title() call
at.header[0].value         # first st.header() call
at.markdown[0].value       # first st.markdown() call

# Metrics
at.metric[0].value         # displayed value
at.metric[0].label         # metric label

# Widgets
at.selectbox[0].value      # current selection
at.selectbox[0].options    # available options
at.date_input[0].value     # current date value

# Data display
at.dataframe[0].value      # DataFrame content

# Containers
at.sidebar.selectbox[0]    # widgets inside st.sidebar
at.columns[0].metric[0]    # metrics inside first st.columns() column

# Status
at.exception               # any unhandled exceptions (falsy when none)
```

## Simulating Interactions

Widget interactions require calling `.run()` afterward to re-execute the app with the new state:

```python
# Select a dropdown value
at.selectbox[0].select("Week").run()

# Click a button
at.button[0].click().run()

# Toggle a checkbox
at.checkbox[0].check().run()

# Set a slider
at.slider[0].set_range(2, 5).run()

# Type into a text input
at.text_input[0].input("search term").run()
```

After `.run()`, query elements again to verify the updated output.

## Mocking External Dependencies

App tests exercise Streamlit rendering, not live data. Always mock external services:

```python
from unittest.mock import patch, MagicMock
import pandas as pd
from streamlit.testing.v1 import AppTest


def test_page_renders():
    """Test that page renders with mocked data."""
    mock_df = pd.DataFrame({
        "date": pd.date_range("2025-01-01", periods=7),
        "count": [1000] * 7,
    })

    with patch("myapp.data.fetch_data", return_value=mock_df):
        at = AppTest.from_file("path/to/pages/my_page.py", default_timeout=10)
        at.run()

    assert not at.exception
    assert len(at.title) > 0
```

### Bypassing `@st.cache_data`

If your data functions use `@st.cache_data`, patching them directly is the simplest approach — the decorator is transparent to mocking. If needed, you can also patch `streamlit.cache_data` to return the unwrapped function:

```python
with patch("streamlit.cache_data", side_effect=lambda **kwargs: lambda fn: fn):
    ...
```

## What to Validate

| Check | Why |
|-------|-----|
| `assert not at.exception` | Page renders without errors |
| Widget options match expected values | Dropdowns and controls are correctly populated |
| Widget defaults are correct | Page loads in expected initial state |
| Interactions update displayed elements | UI responds to user actions |
| Expected number of charts/metrics exist | Layout renders all visual components |
| Sidebar contains expected controls | Page structure is correct |

## What NOT to Do

- **Do not use AppTest for data validation.** Validating query results against live data sources is the `data_e2e_testing` skill's job. App tests use mocked data.
- **Do not test visual styling.** AppTest validates element presence and values, not CSS or layout aesthetics.
- **Do not skip mocking external services.** App tests should run fast in CI, not wait for database queries.
- **Do not test third-party widget internals.** Trust that Plotly charts render when `st.plotly_chart` is called. Verify the chart element exists, not its internal SVG.

## Relationship to Other Testing Skills

| Skill | What it tests | Data source | Runner |
|-------|--------------|-------------|--------|
| `testing` | Query functions, data transforms, pure logic | Mocked/synthetic | pytest |
| `streamlit_testing` | Page rendering, widget interactions, UI flow | Mocked via AppTest | pytest |
| `data_e2e_testing` | Full pipelines against real data | Live database | Standalone scripts |
