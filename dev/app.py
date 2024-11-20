from tkinterdnd2 import TkinterDnD
from ui import FileOrganizerApp

def main():
    root = TkinterDnD.Tk()
    root.title("Advanced File Organizer")
    app = FileOrganizerApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()