import React from "react";

const AuthLayout = ({ children }: { children: React.ReactNode }) => {
  return (
    <div>
      <div>Auth layout</div>
      {children}
    </div>
  );
};

export default AuthLayout;
