def update_status(status_bar, debug_text, message):
    print(message)
    status_bar.config(text=message)
    debug_text.insert('end', f"{message}\n")
    debug_text.see('end')
    status_bar.update_idletasks()

# Add other utility functions as needed 