# We no longer need to modify sys.path here.
# Pytest will be configured to find the module.


def test_greeting_binding():
    """
    Tests the C++ get_greeting function through the Python binding.
    """
    # Import the module inside the test function.
    # This ensures it's imported in the context of the test runner.
    import signalux

    # Call the C++ function
    message = signalux.get_greeting("Pytest")
    # Assert the expected outcome
    assert message == "Hello, Pytest!"
