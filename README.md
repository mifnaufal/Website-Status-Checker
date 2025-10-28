# 🌐 Website Status Checker

A simple and colorful Ruby script to check website status codes and filter only 200 (OK) and 403 (Forbidden) responses.

![Ruby](https://img.shields.io/badge/Ruby-2.5+-red.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

## 🚀 Quick Installation

### Method 1: Direct Download (Easiest)
```bash
# Download the script
curl -O https://raw.githubusercontent.com/mifnaufal/Website-Status-Checker

# Or using wget
wget https://raw.githubusercontent.com/mifnaufal/Website-Status-Checker
```

### Method 2: Clone Repository
```bash
git clone https://github.com/mifnaufal/Website-Status-Checker
cd website-status-checker
```

## 📦 Requirements

- **Ruby** (already installed on most Mac/Linux systems)
- Check if you have Ruby:
  ```bash
  ruby -v
  ```
  If not installed, get it from: https://www.ruby-lang.org/

## 🎯 Simple Usage

### 1. Create your URL list file:
```bash
# Create websites.txt file
cat > websites.txt << EOF
https://google.com
https://github.com
https://example.com
http://nonexistent-site-12345.com
EOF
```

### 2. Run the script:
```bash
ruby status.rb websites.txt -o results.txt
```

### 3. Check results:
```bash
cat results.txt
```

## 📁 File Structure
```
website-status-checker/
├── status.rb          # Main script
├── websites.txt       # Your input URLs (create this)
└── results.txt        # Output file (created automatically)
```

## 🛠️ How It Works

1. **Input**: Put URLs in a text file (one per line)
2. **Scan**: Script checks each website's HTTP status
3. **Filter**: Keeps only status 200 (OK) and 403 (Forbidden)
4. **Output**: Saves filtered results to a new file

## 📝 Example

**Input file (`websites.txt`):**
```
https://google.com
https://github.com
https://httpstat.us/403
http://invalid-site.com
```

**Run command:**
```bash
ruby status.rb websites.txt -o good_sites.txt
```

**Output file (`good_sites.txt`):**
```
https://google.com	200
https://github.com	200
https://httpstat.us/403	403
```

## 🎨 Features

- ✅ Colorful terminal output
- 📊 Live progress display  
- ⏰ 10-second timeout per site
- 🔒 Error handling for dead sites
- 📈 Summary report at the end

## ❓ Common Questions

**Q: I get "ruby: command not found"**
A: Install Ruby from https://www.ruby-lang.org/

**Q: My file isn't found**
A: Make sure your text file is in the same folder as the script

**Q: Script stops on errors**
A: It's designed to continue even if some sites fail

**Q: Can I check different status codes?**
A: Edit line with `[200, 403]` in the script to change codes

## 📄 License

MIT License - feel free to use and modify!

## 🤝 Contributing

Found a bug? Have an idea? Open an issue or pull request!
