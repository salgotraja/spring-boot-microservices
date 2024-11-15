import type { Metadata } from "next";
import "./globals.css";
import localFont from "next/font/local";

const inter = localFont({
  src: "./fonts/InterVF.ttf",
  variable: "--font-inter",
  weight: "100 200 300 400 500 700 800 900",
});

const spaceGrotesk = localFont({
  src: "./fonts/SpaceGroteskVF.ttf",
  variable: "--font-space-grotesk",
  weight: "300 400 500 700",
});

const SITE_TITLE = "Book Store - Your Gateway to Knowledge";
const SITE_DESCRIPTION = "Welcome to the Book Store, where you can explore a vast collection of books from various genres and authors. Discover your next great read today!";
const CREATOR_NAME = "Jagdish Salgotra";
const KEYWORDS = ['books', 'bookstore', 'buy books', 'read', 'literature', 'novels', 'non-fiction', 'bestsellers'];

export const metadata: Metadata = {
  title: SITE_TITLE,
  description: SITE_DESCRIPTION,
  referrer: "origin-when-cross-origin",
  keywords: KEYWORDS,
  creator: CREATOR_NAME,
  publisher: CREATOR_NAME,
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${inter.className} ${spaceGrotesk.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
