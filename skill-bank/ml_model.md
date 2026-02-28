# Skill Template: ML Model

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific ML libraries, experiment tracking setup, and data sources.

## When to Use

Use this skill for tasks involving ML model development — training, evaluation, prediction, and experiment tracking.

## Library Selection

| Use case | Library |
|----------|---------|
| Causal inference / intervention analysis | econml |
| Standard classification and regression | scikit-learn |
| Gradient boosting (when performance matters) | XGBoost |
| Experiment tracking, metrics, model registry | MLflow |

When in doubt: if the task involves measuring the causal effect of an action (treatment), use econml. For everything else, start with scikit-learn and move to XGBoost if performance requires it.

## Code Structure

Each model gets its own directory:

```
{project}/models/{model_name}/
├── __init__.py
├── train.py          # Training pipeline
├── evaluate.py       # Evaluation metrics and reporting
└── predict.py        # Prediction/inference
```

### train.py

```python
import mlflow
import pandas as pd
from sklearn.model_selection import train_test_split


def load_training_data() -> pd.DataFrame:
    """Load transformed data from the data warehouse."""
    # Query from mart/analytics tables, not raw source data
    ...


def train(params: dict | None = None):
    """Train the model and log to MLflow."""
    df = load_training_data()
    X = df.drop(columns=["target"])
    y = df["target"]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    with mlflow.start_run():
        mlflow.log_params(params or {})

        model = ...  # Instantiate and fit
        model.fit(X_train, y_train)

        metrics = evaluate(model, X_test, y_test)
        mlflow.log_metrics(metrics)
        mlflow.sklearn.log_model(model, "model")

    return model
```

### evaluate.py

```python
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score


def evaluate(model, X_test, y_test) -> dict:
    """Evaluate model and return metrics dict."""
    y_pred = model.predict(X_test)
    return {
        "accuracy": accuracy_score(y_test, y_pred),
        "precision": precision_score(y_test, y_pred, average="weighted"),
        "recall": recall_score(y_test, y_pred, average="weighted"),
        "f1": f1_score(y_test, y_pred, average="weighted"),
    }
```

### predict.py

```python
import mlflow


def load_model(model_uri: str):
    """Load a model from MLflow registry."""
    return mlflow.pyfunc.load_model(model_uri)


def predict(model, input_data):
    """Generate predictions."""
    return model.predict(input_data)
```

## econml Pattern

For causal/intervention models:

```python
from econml.dml import CausalForestDML

def train_causal_model(df):
    """Train a causal model to estimate treatment effects."""
    Y = df["outcome"]           # Outcome variable
    T = df["treatment"]         # Treatment indicator
    X = df[feature_columns]     # Features for heterogeneous effects
    W = df[confound_columns]    # Confounders to control for

    model = CausalForestDML(
        model_y="auto",
        model_t="auto",
        n_estimators=100,
        random_state=42,
    )
    model.fit(Y, T, X=X, W=W)
    return model
```

## MLflow Requirements

Every experiment must be tracked:
- `mlflow.log_params()` — all hyperparameters
- `mlflow.log_metrics()` — all evaluation metrics
- `mlflow.log_model()` — the trained model artifact
- `mlflow.log_artifact()` — feature importance plots, confusion matrices, etc.
- Set experiment name: `mlflow.set_experiment("{project}/{model_name}")`

## Data Loading

Models read from warehouse mart/analytics tables (post-transformation). Never read raw source data directly for training.

## Artifact Storage

- Use MLflow model registry for model versioning
- Serialise models with joblib (for sklearn/xgboost) or MLflow's built-in serialisation
- Store feature importance and evaluation plots as MLflow artifacts

## Testing

- Test data preprocessing functions with small synthetic DataFrames
- Test evaluation functions with known inputs and expected outputs
- Mock database clients for data loading tests
- Mock MLflow for training pipeline tests
