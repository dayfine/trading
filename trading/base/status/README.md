# Status Module

Standard status handling for the trading system. Based on [Abseil's status codes](https://abseil.io/docs/cpp/guides/status-codes).

## Overview

This module provides a standardized way to handle operation status across the trading system. It defines:
- A set of status codes that cover both success and failure scenarios
- A standard status type that includes both a code and a descriptive message
- Helper functions for creating and working with status values
