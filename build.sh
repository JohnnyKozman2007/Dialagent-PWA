#!/bin/bash

# Install Flutter
echo "📦 Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# Pre-cache Flutter
flutter precache

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Build the web app
echo "🚀 Building web app..."
flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

echo "✅ Build complete! Output in build/web"
