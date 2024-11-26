import React from "react";

const RootLayout = ({ children }: { children: React.ReactNode }) => {
  return (
    <main>
      <div></div>
      {children}
    </main>
  );
};

export default RootLayout;
