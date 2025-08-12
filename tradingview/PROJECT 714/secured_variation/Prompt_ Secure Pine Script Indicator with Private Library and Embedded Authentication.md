# Prompt: Secure Pine Script Indicator with Private Library and Embedded Authentication

## Goal

Refactor a given open-source Pine Script indicator by extracting its core functional logic into a new private library. This library will incorporate a robust, embedded user authentication mechanism. The original indicator will then be transformed into a protected version that imports and utilizes this secure library, ensuring that only authorized users can access its full functionality.

## Input

Provide the complete Pine Script code of the open-source indicator that needs to be secured. The code should be provided as a text file attachment.

## Output

Upon successful completion, the following will be delivered:

1.  **`AuthLib_New.pine`**: The Pine Script code for the new private library. This library will contain the extracted core functions, each with an embedded authentication check. Unauthorized calls to these functions will result in `na` (Not Available) values or `false` where appropriate, rendering the indicator non-functional.
2.  **`Protected_Indicator_New.pine`**: The Pine Script code for the refactored main indicator. This script will import `AuthLib_New.pine` and replace its original core logic with calls to the corresponding functions within the library. It will retain all user inputs and plotting/drawing commands.
3.  **`Implementation_Guide_New.md`**: A comprehensive Markdown document detailing the step-by-step process for publishing both the private library and the protected indicator on TradingView, managing authorized users, and troubleshooting common issues.

## Process & Guidelines

Follow these phases to achieve the desired outcome:

### Phase 1: Analyze the Provided Pine Script Code

*   **Objective**: Gain a thorough understanding of the indicator's functionality, structure, and dependencies.
*   **Action**: Read through the entire provided Pine Script code. Identify its primary purpose, how it processes data, and what visual elements it generates.
*   **Key Focus**: Understand the flow of execution and the role of different sections (inputs, calculations, plotting, alerts).

### Phase 2: Design the Security Architecture and Identify Core Functions to Protect

*   **Objective**: Determine which parts of the code constitute the 


core intellectual property and how the authentication will be integrated.
*   **Action**: 
    *   **Identify Core Functions**: Pinpoint the specific functions, calculations, and logic blocks that represent the unique value or 


secret sauce of the indicator. These are the parts that will be moved to the private library.
    *   **Define Library Structure**: Outline the functions that will be `export`ed from the private library and their expected parameters and return types. Consider how these functions will replace the original logic in the main indicator.
    *   **Authentication Integration Strategy**: Confirm that the authentication check (`_isUserAuthorized()`) will be embedded at the beginning of *every* exported core function within the library. This ensures that if the user is unauthorized, the function returns `na` or `false`, rendering the output non-functional.

### Phase 3: Create the Private Library with Embedded Authentication

*   **Objective**: Develop the `AuthLib_New.pine` script, containing the protected core logic.
*   **Action**: 
    *   **Initialize Library**: Create a new Pine Script file starting with `library("AuthLib_New", overlay=true)`.
    *   **Implement User Database**: Include a `var string[] authorizedUsers` array to store authorized TradingView usernames. Initialize it with a placeholder for the user's own username and a comment for adding others.
    *   **Implement Internal Authentication Function**: Create a private function `_isUserAuthorized()` that checks `chart.username` against the `authorizedUsers` array.
    *   **Extract and Protect Core Functions**: Move the identified core functions from the original indicator into this library. For each extracted function:
        *   Add the `export` keyword.
        *   At the very beginning of the function, add an `if not _isUserAuthorized(): return na` (or `false`, `0`, etc., depending on the function's return type) statement.
        *   Ensure all necessary variables and calculations are self-contained or passed as parameters.

### Phase 4: Create the Refactored Main Indicator Script

*   **Objective**: Develop the `Protected_Indicator_New.pine` script, which will serve as the public-facing, protected version of the indicator.
*   **Action**: 
    *   **Initialize Indicator**: Create a new Pine Script file starting with `indicator(...)`.
    *   **Copy Inputs**: Transfer all `input.*` declarations from the original script to this new indicator. These should remain in the main script as they control user-facing settings.
    *   **Import Library**: Add an `import YourUsername/AuthLib_New/1 as core` statement at the top of the script (adjust `YourUsername` and version as necessary).
    *   **Replace Core Logic Calls**: Replace the original core calculation and drawing logic with calls to the corresponding `core.functionName(...)` functions from the imported library.
    *   **Handle `na` Values**: Ensure that any plotting or drawing functions in the main script gracefully handle `na` values that might be returned by the library functions if the user is unauthorized (e.g., `plot(value)` will automatically not plot `na`).
    *   **Remove Redundant Code**: Delete any functions or variables that were moved to the library and are no longer needed in the main script.

### Phase 5: Provide Implementation Guidance and Deliver Results

*   **Objective**: Furnish the user with clear instructions for deploying and managing the secured indicator.
*   **Action**: 
    *   **Generate `Implementation_Guide_New.md`**: Create a Markdown document detailing:
        *   **Publishing the Library**: Step-by-step instructions for publishing `AuthLib_New.pine` as a **Private** library on TradingView.
        *   **Publishing the Indicator**: Step-by-step instructions for publishing `Protected_Indicator_New.pine` as an **Invite-Only** indicator on TradingView.
        *   **Managing Users**: Clear guidance on how to add or remove authorized users by editing the `authorizedUsers` array in `AuthLib_New.pine` and republishing the library (and potentially the main indicator to update the version number).
        *   **Security Explanation**: Reiterate the security benefits of this approach (embedded authentication, hidden source code).
        *   **Troubleshooting**: Common issues and their solutions (e.g., indicator not showing, import errors).
    *   **Deliver Files**: Provide the user with `AuthLib_New.pine`, `Protected_Indicator_New.pine`, and `Implementation_Guide_New.md` as attachments.

## Constraints & Considerations

*   **Pine Script Version**: All code must be `//@version=5`.
*   **Library Limitations**: Remember that library functions cannot directly use `input()`, `plot()`, `fill()`, `bgcolor()`, etc. All user inputs and visual outputs must be handled by the main indicator.
*   **Usernames**: Emphasize the importance of exact (case-sensitive) TradingView usernames for authorization.
*   **Version Control**: Highlight the need to update the library version in the `import` statement of the main indicator whenever the library is republished with changes.
*   **Complexity**: For extremely large or complex indicators, breaking down core functions might require careful planning to maintain functionality and variable scope.

This prompt provides a comprehensive framework for securing your Pine Script indicators. When you provide a new open-source Pine Script, I will follow these steps to deliver the protected version.

